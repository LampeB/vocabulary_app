BEGIN;

-- Keep the IDs already stored by devices. Uniqueness and references now
-- include the owner, so two accounts may submit the same client UUID safely.
ALTER TABLE public.concepts ADD COLUMN owner_id uuid;
ALTER TABLE public.word_variants ADD COLUMN owner_id uuid;
ALTER TABLE public.variant_progress ADD COLUMN variant_owner_id uuid;
ALTER TABLE public.challenges ADD COLUMN list_owner_id uuid;

-- Backfill every row, including old immutable tombstones. The locks stay
-- held through COMMIT while the guards and keys are being replaced.
ALTER TABLE public.concepts DISABLE TRIGGER concepts_guard_tombstone;
ALTER TABLE public.word_variants DISABLE TRIGGER word_variants_guard_tombstone;
ALTER TABLE public.variant_progress DISABLE TRIGGER e2e_guard_shared_write;
ALTER TABLE public.challenges DISABLE TRIGGER e2e_guard_shared_write;
UPDATE public.concepts c SET owner_id = l.owner_id
FROM public.vocabulary_lists l WHERE l.id = c.list_id;
UPDATE public.word_variants w SET owner_id = c.owner_id
FROM public.concepts c WHERE c.id = w.concept_id;
UPDATE public.variant_progress p SET variant_owner_id = w.owner_id
FROM public.word_variants w WHERE w.id = p.variant_id;
UPDATE public.challenges ch SET list_owner_id = l.owner_id
FROM public.vocabulary_lists l WHERE l.id = ch.list_id;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE owner_id IS NULL)
    OR EXISTS (SELECT 1 FROM public.concepts WHERE owner_id IS NULL)
    OR EXISTS (SELECT 1 FROM public.word_variants WHERE owner_id IS NULL)
    OR EXISTS (SELECT 1 FROM public.variant_progress WHERE user_id IS NULL) THEN
    RAISE EXCEPTION 'Vocabulary namespace requires an owner for every existing vocabulary and progress row';
  END IF;
END $$;

ALTER TABLE public.concepts DROP CONSTRAINT concepts_list_id_fkey;
ALTER TABLE public.word_variants DROP CONSTRAINT word_variants_concept_id_fkey;
ALTER TABLE public.variant_progress
  DROP CONSTRAINT variant_progress_variant_id_fkey,
  DROP CONSTRAINT variant_progress_user_id_variant_id_direction_key;
ALTER TABLE public.challenges DROP CONSTRAINT challenges_list_id_fkey;

ALTER TABLE public.vocabulary_lists
  DROP CONSTRAINT vocabulary_lists_pkey,
  ADD PRIMARY KEY (owner_id, id);
ALTER TABLE public.concepts
  DROP CONSTRAINT concepts_pkey,
  ADD PRIMARY KEY (owner_id, id),
  ADD CONSTRAINT concepts_owner_list_fkey FOREIGN KEY (owner_id, list_id)
    REFERENCES public.vocabulary_lists(owner_id, id) ON DELETE CASCADE;
ALTER TABLE public.word_variants
  DROP CONSTRAINT word_variants_pkey,
  ADD PRIMARY KEY (owner_id, id),
  ADD CONSTRAINT variants_owner_concept_fkey FOREIGN KEY (owner_id, concept_id)
    REFERENCES public.concepts(owner_id, id) ON DELETE CASCADE;
ALTER TABLE public.variant_progress
  DROP CONSTRAINT variant_progress_pkey,
  ADD PRIMARY KEY (user_id, id),
  ADD UNIQUE (user_id, variant_owner_id, variant_id, direction),
  ADD CONSTRAINT progress_owner_variant_fkey FOREIGN KEY (variant_owner_id, variant_id)
    REFERENCES public.word_variants(owner_id, id) MATCH FULL ON DELETE CASCADE;
ALTER TABLE public.challenges
  ADD CONSTRAINT challenges_owner_list_fkey FOREIGN KEY (list_owner_id, list_id)
    REFERENCES public.vocabulary_lists(owner_id, id) MATCH FULL;

CREATE INDEX idx_concepts_owner_list ON public.concepts (owner_id, list_id, id);
CREATE INDEX idx_variants_owner_concept ON public.word_variants (owner_id, concept_id);
CREATE INDEX idx_progress_owner_variant ON public.variant_progress (variant_owner_id, variant_id);
CREATE INDEX idx_challenges_owner_list ON public.challenges (list_owner_id, list_id);

-- Current clients send owner IDs explicitly. Legacy clients and admin imports
-- may omit them. Select an unqualified parent only if its ID is unambiguous.
CREATE FUNCTION public.bind_vocabulary_owner()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'concepts' THEN
      NEW.owner_id := COALESCE(NEW.owner_id, auth.uid(), (
        SELECT min(l.owner_id::text)::uuid FROM public.vocabulary_lists l
        WHERE l.id = NEW.list_id HAVING count(*) = 1));
    WHEN 'word_variants' THEN
      NEW.owner_id := COALESCE(NEW.owner_id, auth.uid(), (
        SELECT min(c.owner_id::text)::uuid FROM public.concepts c
        WHERE c.id = NEW.concept_id HAVING count(*) = 1));
    WHEN 'variant_progress' THEN
      IF TG_OP = 'UPDATE' AND NEW.variant_id IS DISTINCT FROM OLD.variant_id
          AND NEW.variant_owner_id IS NOT DISTINCT FROM OLD.variant_owner_id THEN
        NEW.variant_owner_id := NULL;
      END IF;
      IF NEW.variant_id IS NOT NULL THEN
        NEW.variant_owner_id := COALESCE(NEW.variant_owner_id, (
          SELECT v.owner_id FROM public.word_variants v
          WHERE v.id = NEW.variant_id AND v.owner_id = NEW.user_id
        ), (
          SELECT min(v.owner_id::text)::uuid FROM public.word_variants v
          WHERE v.id = NEW.variant_id HAVING count(*) = 1
        ));
      END IF;
    WHEN 'challenges' THEN
      IF TG_OP = 'UPDATE' AND NEW.list_id IS DISTINCT FROM OLD.list_id
          AND NEW.list_owner_id IS NOT DISTINCT FROM OLD.list_owner_id THEN
        NEW.list_owner_id := NULL;
      END IF;
      IF NEW.list_id IS NOT NULL THEN
        NEW.list_owner_id := COALESCE(NEW.list_owner_id, (
          SELECT l.owner_id FROM public.vocabulary_lists l
          WHERE l.id = NEW.list_id AND l.owner_id = NEW.challenger_id
        ), (
          SELECT min(l.owner_id::text)::uuid FROM public.vocabulary_lists l
          WHERE l.id = NEW.list_id HAVING count(*) = 1
        ));
      END IF;
  END CASE;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.bind_vocabulary_owner() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER bind_vocabulary_owner BEFORE INSERT ON public.concepts
  FOR EACH ROW EXECUTE FUNCTION public.bind_vocabulary_owner();
CREATE TRIGGER bind_vocabulary_owner BEFORE INSERT ON public.word_variants
  FOR EACH ROW EXECUTE FUNCTION public.bind_vocabulary_owner();
CREATE TRIGGER bind_vocabulary_owner BEFORE INSERT OR UPDATE ON public.variant_progress
  FOR EACH ROW EXECUTE FUNCTION public.bind_vocabulary_owner();
CREATE TRIGGER bind_vocabulary_owner BEFORE INSERT OR UPDATE ON public.challenges
  FOR EACH ROW EXECUTE FUNCTION public.bind_vocabulary_owner();

ALTER POLICY concepts_via_list ON public.concepts
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid() AND list_id IS NOT NULL);
ALTER POLICY variants_via_concept ON public.word_variants
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid() AND concept_id IS NOT NULL);
ALTER POLICY concepts_public_read ON public.concepts
  USING (is_deleted IS NOT TRUE AND EXISTS (
    SELECT 1 FROM public.vocabulary_lists l
    WHERE l.owner_id = concepts.owner_id AND l.id = concepts.list_id
      AND l.visibility = 'public' AND l.is_deleted IS NOT TRUE
  ));
ALTER POLICY variants_public_read ON public.word_variants
  USING (is_deleted IS NOT TRUE AND EXISTS (
    SELECT 1 FROM public.concepts c
    JOIN public.vocabulary_lists l ON l.owner_id = c.owner_id AND l.id = c.list_id
    WHERE c.owner_id = word_variants.owner_id AND c.id = word_variants.concept_id
      AND c.is_deleted IS NOT TRUE AND l.visibility = 'public' AND l.is_deleted IS NOT TRUE
  ));

-- Preserve 014's locking and deletion rules within the owner namespace.
CREATE OR REPLACE FUNCTION public.guard_vocabulary_child_tombstone()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  parent_list_id uuid;
  parent_concept_deleted boolean;
  parent_list_deleted boolean;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_deleted THEN RETURN OLD; END IF;
    NEW.owner_id := OLD.owner_id;
    IF TG_TABLE_NAME = 'concepts' THEN
      NEW.list_id := OLD.list_id;
    ELSE
      NEW.concept_id := OLD.concept_id;
    END IF;
  END IF;
  IF TG_TABLE_NAME = 'concepts' THEN
    parent_list_id := NEW.list_id;
  ELSE
    SELECT c.list_id, c.is_deleted INTO parent_list_id, parent_concept_deleted
    FROM public.concepts c
    WHERE c.owner_id = NEW.owner_id AND c.id = NEW.concept_id FOR SHARE;
  END IF;
  SELECT l.is_deleted INTO parent_list_deleted FROM public.vocabulary_lists l
  WHERE l.owner_id = NEW.owner_id AND l.id = parent_list_id FOR SHARE;
  IF parent_concept_deleted OR parent_list_deleted THEN
    IF TG_OP = 'UPDATE' THEN NEW := OLD; END IF;
    NEW.is_deleted := true;
  END IF;
  RETURN NEW;
END $$;

-- Migrations 008 and 009 also match relationships through vocabulary IDs.
-- Preserve scenario authorization and fail-closed reset after scoping them.
CREATE OR REPLACE FUNCTION e2e_private.guard_shared_write()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  participants uuid[];
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'friend_requests' THEN
      participants := ARRAY[NEW.from_user_id, NEW.to_user_id];
    WHEN 'friendships' THEN
      participants := ARRAY[NEW.user_a_id, NEW.user_b_id];
    WHEN 'challenges' THEN
      participants := ARRAY[NEW.challenger_id, NEW.challenged_id, NEW.list_owner_id];
    WHEN 'variant_progress' THEN
      IF NEW.user_id IS NOT DISTINCT FROM NEW.variant_owner_id THEN RETURN NEW; END IF;
      participants := ARRAY[NEW.user_id, NEW.variant_owner_id];
  END CASE;
  IF EXISTS (SELECT 1 FROM e2e_private.accounts
    WHERE user_id = ANY(participants) AND scenario_id IS NOT NULL) THEN
    RAISE EXCEPTION 'E2E scenario accounts cannot share relationships or progress'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION e2e_private.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  registered text;
  result jsonb;
BEGIN
  SELECT scenario_id INTO registered FROM e2e_private.accounts WHERE user_id = uid FOR UPDATE;
  IF uid IS NULL OR registered IS NULL OR p_scenario_id IS NULL
      OR registered <> p_scenario_id THEN
    RAISE EXCEPTION 'Account does not belong to this E2E scenario' USING ERRCODE = '42501';
  END IF;
  LOCK TABLE public.vocabulary_lists, public.concepts, public.word_variants,
    public.variant_progress, public.friendships, public.friend_requests,
    public.challenges IN SHARE ROW EXCLUSIVE MODE;
  IF EXISTS (SELECT 1 FROM public.friendships WHERE user_a_id = uid OR user_b_id = uid)
    OR EXISTS (SELECT 1 FROM public.friend_requests WHERE from_user_id = uid OR to_user_id = uid)
    OR EXISTS (SELECT 1 FROM public.challenges WHERE challenger_id = uid OR challenged_id = uid
      OR list_owner_id = uid)
    OR EXISTS (SELECT 1 FROM public.variant_progress
      WHERE variant_owner_id = uid AND user_id IS DISTINCT FROM uid)
  THEN
    RAISE EXCEPTION 'E2E account has shared data; reset refused to protect other accounts'
      USING ERRCODE = '23503';
  END IF;
  result := e2e_private.reset_e2e_account();
  RETURN result || jsonb_build_object('scenario_id', registered);
END $$;

CREATE OR REPLACE FUNCTION e2e_private.reset_e2e_account()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  baseline_username text;
  history_table text;
  remaining boolean;
BEGIN
  SELECT username INTO baseline_username FROM e2e_private.accounts
    WHERE user_id = uid FOR UPDATE;
  IF uid IS NULL OR baseline_username IS NULL THEN
    RAISE EXCEPTION 'This account is not enrolled for E2E reset' USING ERRCODE = '42501';
  END IF;
  FOREACH history_table IN ARRAY ARRAY['review_events', 'quiz_sessions', 'grammar_progress'] LOOP
    IF to_regclass('public.' || history_table) IS NOT NULL THEN
      EXECUTE format('DELETE FROM public.%I WHERE user_id = $1', history_table) USING uid;
      EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I WHERE user_id = $1)', history_table)
        INTO remaining USING uid;
      IF remaining THEN RAISE EXCEPTION 'E2E history reset failed'; END IF;
    END IF;
  END LOOP;
  DELETE FROM public.challenges WHERE challenger_id = uid OR challenged_id = uid OR list_owner_id = uid;
  DELETE FROM public.friend_requests WHERE from_user_id = uid OR to_user_id = uid;
  DELETE FROM public.friendships WHERE user_a_id = uid OR user_b_id = uid;
  DELETE FROM public.notifications WHERE user_id = uid;
  DELETE FROM public.leaderboard_entries WHERE user_id = uid;
  DELETE FROM public.subscriptions WHERE user_id = uid;
  DELETE FROM public.variant_progress WHERE user_id = uid;
  DELETE FROM public.vocabulary_lists WHERE owner_id = uid;
  DELETE FROM public.profiles WHERE id = uid;
  INSERT INTO public.profiles (id, username, display_name)
    VALUES (uid, baseline_username, baseline_username);

  IF EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE owner_id = uid)
  OR EXISTS (SELECT 1 FROM public.variant_progress WHERE user_id = uid)
  OR EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = uid)
  OR EXISTS (SELECT 1 FROM public.friend_requests WHERE from_user_id = uid OR to_user_id = uid)
  OR EXISTS (SELECT 1 FROM public.friendships WHERE user_a_id = uid OR user_b_id = uid)
  OR EXISTS (SELECT 1 FROM public.challenges WHERE challenger_id = uid OR challenged_id = uid)
  THEN RAISE EXCEPTION 'E2E reset postcondition failed'; END IF;
  RETURN jsonb_build_object('user_id', uid, 'baseline', 'empty-free-v1',
    'username', baseline_username);
END $$;

ALTER TABLE public.concepts ENABLE TRIGGER concepts_guard_tombstone;
ALTER TABLE public.word_variants ENABLE TRIGGER word_variants_guard_tombstone;
ALTER TABLE public.variant_progress ENABLE TRIGGER e2e_guard_shared_write;
ALTER TABLE public.challenges ENABLE TRIGGER e2e_guard_shared_write;

-- This versioned response admits Patrol only on the schema it exercises.
CREATE FUNCTION public.e2e_patrol_contract()
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Migration 016 installs the sync-write gate. Resolve the function only
  -- after it exists so partially migrated backends can refuse Patrol safely.
  IF to_regprocedure('public.vocabulary_sync_write_ready()') IS NULL THEN RETURN NULL; END IF;
  IF public.vocabulary_sync_write_ready() IS DISTINCT FROM true THEN RETURN NULL; END IF;
  RETURN (SELECT CASE WHEN public.e2e_isolation_ready()
    AND (SELECT count(*) = 3 FROM pg_catalog.pg_trigger
      WHERE tgenabled IN ('O', 'A') AND (
        (tgrelid = to_regclass('public.vocabulary_lists')
         AND tgname = 'vocabulary_lists_keep_tombstone' AND tgtype = 19
         AND tgfoid = to_regprocedure('public.keep_vocabulary_tombstone()'))
        OR (tgfoid = to_regprocedure('public.guard_vocabulary_child_tombstone()') AND tgtype = 23
            AND ((tgrelid = to_regclass('public.concepts') AND tgname = 'concepts_guard_tombstone')
              OR (tgrelid = to_regclass('public.word_variants') AND tgname = 'word_variants_guard_tombstone')))))
    AND (SELECT count(*) = 3 FROM pg_catalog.pg_constraint
      WHERE contype = 'p'
        AND conrelid IN (to_regclass('public.vocabulary_lists'), to_regclass('public.concepts'),
                        to_regclass('public.word_variants'))
        AND pg_catalog.pg_get_constraintdef(oid) = 'PRIMARY KEY (owner_id, id)')
    AND EXISTS (SELECT 1 FROM pg_catalog.pg_constraint
      WHERE contype = 'u' AND conrelid = to_regclass('public.variant_progress')
        AND pg_catalog.pg_get_constraintdef(oid) = 'UNIQUE (user_id, variant_owner_id, variant_id, direction)')
    THEN 'write-order-v1' END);
END $$;
REVOKE ALL ON FUNCTION public.e2e_patrol_contract() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.e2e_patrol_contract() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.reset_e2e_account(p_scenario_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF public.e2e_patrol_contract() IS DISTINCT FROM 'challenge-boundaries-v1' THEN
    RAISE EXCEPTION 'Patrol schema is unavailable; reset refused' USING ERRCODE = '55000';
  END IF;
  RETURN e2e_private.reset_e2e_account(p_scenario_id);
END $$;
-- Migration 019 enables execution once the full Patrol schema is ready.
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
