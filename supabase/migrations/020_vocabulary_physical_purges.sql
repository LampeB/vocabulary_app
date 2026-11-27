BEGIN;

-- Upgrade both released forms of 017 without rebuilding its journal.
CREATE INDEX IF NOT EXISTS pull_physically_removed_lists
  ON vocabulary_private.pull_changes(owner_id, item_id)
  WHERE kind = 'list' AND deleted_list;

CREATE TABLE vocabulary_private.vocabulary_identities (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('list', 'concept', 'variant')),
  item_id uuid NOT NULL,
  parent_id uuid,
  purged boolean NOT NULL DEFAULT false,
  PRIMARY KEY (owner_id, kind, item_id)
);
REVOKE ALL ON vocabulary_private.vocabulary_identities FROM PUBLIC, anon, authenticated;
CREATE INDEX vocabulary_purges_by_parent
  ON vocabulary_private.vocabulary_identities(owner_id, kind, parent_id, item_id)
  WHERE purged;

INSERT INTO vocabulary_private.vocabulary_identities(owner_id,kind,item_id,purged)
  SELECT owner_id,'list',item_id,true FROM vocabulary_private.pull_changes
  WHERE kind='list' AND deleted_list;

CREATE OR REPLACE FUNCTION vocabulary_private.record_vocabulary_pull_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  owner uuid;
  item uuid;
  item_direction text := '';
  item_kind text := 'list';
  new_revision bigint;
  removed_list boolean := false;
  identity_kind text;
  identity_id uuid;
  identity_parent uuid;
BEGIN
  IF TG_OP = 'UPDATE' AND to_jsonb(NEW) = to_jsonb(OLD) THEN RETURN NULL; END IF;
  IF TG_OP = 'DELETE' THEN
    owner := OLD.owner_id;
    -- Removing an account cascades through its rows and their identities.
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = owner) THEN RETURN NULL; END IF;
    identity_id := OLD.id;
    CASE TG_TABLE_NAME
      WHEN 'vocabulary_lists' THEN
        identity_kind := 'list';
        item := OLD.id;
        removed_list := true;
      WHEN 'concepts' THEN
        identity_kind := 'concept';
        identity_parent := OLD.list_id;
        item := OLD.list_id;
      WHEN 'word_variants' THEN
        identity_kind := 'variant';
        identity_parent := OLD.concept_id;
        SELECT c.list_id INTO item FROM public.concepts c
          WHERE c.owner_id=owner AND c.id=OLD.concept_id;
    END CASE;
    INSERT INTO vocabulary_private.vocabulary_identities
      (owner_id,kind,item_id,parent_id,purged)
      VALUES (owner,identity_kind,identity_id,identity_parent,true)
      ON CONFLICT (owner_id,kind,item_id) DO UPDATE
        SET purged=true,parent_id=excluded.parent_id;
  ELSIF TG_TABLE_NAME = 'vocabulary_lists' THEN
    owner := NEW.owner_id;
    item := NEW.id;
  ELSIF TG_TABLE_NAME = 'concepts' THEN
    owner := NEW.owner_id;
    item := NEW.list_id;
  ELSIF TG_TABLE_NAME = 'word_variants' THEN
    owner := NEW.owner_id;
    SELECT c.list_id INTO item FROM public.concepts c
      WHERE c.owner_id = owner AND c.id = NEW.concept_id;
  ELSE
    IF NEW.variant_owner_id IS DISTINCT FROM NEW.user_id THEN RETURN NULL; END IF;
    item_kind := 'progress';
    owner := NEW.user_id;
    item := NEW.variant_id;
    item_direction := NEW.direction;
  END IF;
  IF item IS NULL OR owner IS NULL THEN RETURN NULL; END IF;

  INSERT INTO vocabulary_private.pull_watermarks AS watermark(owner_id, revision)
    VALUES (owner, 1)
    ON CONFLICT (owner_id) DO UPDATE SET revision = watermark.revision + 1
    RETURNING revision INTO new_revision;
  INSERT INTO vocabulary_private.pull_changes AS change
    (owner_id, kind, item_id, direction, revision, deleted_list)
    VALUES (owner, item_kind, item, item_direction, new_revision, removed_list)
    ON CONFLICT (owner_id, kind, item_id, direction) DO UPDATE
    SET revision = excluded.revision,
        deleted_list = change.deleted_list OR excluded.deleted_list;
  RETURN NULL;
END $$;

CREATE FUNCTION vocabulary_private.purged_child_tombstone(
  p_kind text, p_owner_id uuid, p_id uuid, p_parent_id uuid
) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'id', p_id, 'owner_id', p_owner_id, 'is_deleted', true,
    'created_at', '1970-01-01T00:00:00Z', 'updated_at', '1970-01-01T00:00:00Z')
    || CASE WHEN p_kind='concept'
      THEN jsonb_build_object('list_id',p_parent_id,'word_variants','[]'::jsonb)
      ELSE jsonb_build_object('concept_id',p_parent_id) END;
$$;
REVOKE ALL ON FUNCTION vocabulary_private.purged_child_tombstone(text,uuid,uuid,uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION vocabulary_private.purged_list_tombstone(p_owner_id uuid, p_list_id uuid)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'id', p_list_id, 'owner_id', p_owner_id, 'is_deleted', true, 'name', '',
    'created_at', '1970-01-01T00:00:00Z', 'updated_at', '1970-01-01T00:00:00Z');
$$;
REVOKE ALL ON FUNCTION vocabulary_private.purged_list_tombstone(uuid,uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.vocabulary_pull_inventory(p_owner_id uuid, p_after_id uuid)
RETURNS SETOF public.vocabulary_lists
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT (inventory.row_data).*
  FROM (
    (SELECT l.id, l AS row_data FROM public.vocabulary_lists l
     WHERE l.owner_id = p_owner_id AND p_owner_id = auth.uid()
       AND (p_after_id IS NULL OR l.id > p_after_id)
     ORDER BY l.id LIMIT 500)
    UNION ALL
    (SELECT c.item_id, jsonb_populate_record(NULL::public.vocabulary_lists,
       vocabulary_private.purged_list_tombstone(c.owner_id, c.item_id))
     FROM vocabulary_private.pull_changes c
     WHERE c.owner_id = p_owner_id AND p_owner_id = auth.uid()
       AND c.kind = 'list' AND c.deleted_list
       AND (p_after_id IS NULL OR c.item_id > p_after_id)
     ORDER BY c.item_id LIMIT 500)
  ) AS inventory
  ORDER BY inventory.id LIMIT 500;
$$;

CREATE FUNCTION public.vocabulary_pull_concepts(p_owner_id uuid, p_list_id uuid, p_after_id uuid)
RETURNS TABLE(id uuid, value jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT page.id, page.value || CASE WHEN page.purged THEN '{}'::jsonb
    ELSE jsonb_build_object('word_variants', COALESCE((
      SELECT jsonb_agg(variant.value ORDER BY variant.id) FROM (
        SELECT w.id, to_jsonb(w) AS value FROM public.word_variants w
        WHERE w.owner_id=p_owner_id AND w.concept_id=page.id
        UNION ALL
        SELECT i.item_id, vocabulary_private.purged_child_tombstone(
          'variant',i.owner_id,i.item_id,i.parent_id)
        FROM vocabulary_private.vocabulary_identities i
        WHERE i.owner_id=p_owner_id AND i.kind='variant' AND i.purged AND i.parent_id=page.id
      ) AS variant
    ), '[]'::jsonb)) END
  FROM (
    (SELECT c.id, to_jsonb(c) AS value, false AS purged FROM public.concepts c
     WHERE c.owner_id=p_owner_id AND p_owner_id=auth.uid() AND c.list_id=p_list_id
       AND (p_after_id IS NULL OR c.id>p_after_id)
     ORDER BY c.id LIMIT 500)
    UNION ALL
    (SELECT i.item_id, vocabulary_private.purged_child_tombstone('concept',i.owner_id,i.item_id,i.parent_id), true
     FROM vocabulary_private.vocabulary_identities i
     WHERE i.owner_id=p_owner_id AND p_owner_id=auth.uid() AND i.kind='concept'
       AND i.purged AND i.parent_id=p_list_id AND (p_after_id IS NULL OR i.item_id>p_after_id)
     ORDER BY i.item_id LIMIT 500)
    ORDER BY id LIMIT 500
  ) AS page
  ORDER BY page.id;
$$;

CREATE OR REPLACE FUNCTION public.vocabulary_pull_changed_lists(
  p_owner_id uuid, p_after bigint, p_through bigint
) RETURNS TABLE (revision bigint, value jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT c.revision, COALESCE(to_jsonb(l),
      vocabulary_private.purged_list_tombstone(c.owner_id, c.item_id))
    FROM vocabulary_private.pull_changes c
    LEFT JOIN public.vocabulary_lists l ON l.owner_id = c.owner_id AND l.id = c.item_id
    WHERE c.owner_id = p_owner_id AND p_owner_id = auth.uid() AND c.kind = 'list'
      AND c.revision > p_after AND c.revision <= p_through
      AND (l.id IS NOT NULL OR c.deleted_list)
    ORDER BY c.revision LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION public.vocabulary_pull_changed_progress(
  p_owner_id uuid, p_after bigint, p_through bigint
) RETURNS TABLE (revision bigint, value jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT c.revision, to_jsonb(p)
    FROM vocabulary_private.pull_changes c
    JOIN public.variant_progress p ON p.user_id = c.owner_id AND p.variant_owner_id = c.owner_id
      AND p.variant_id = c.item_id AND p.direction = c.direction
    WHERE c.owner_id = p_owner_id AND p_owner_id = auth.uid() AND c.kind = 'progress'
      AND c.revision > p_after AND c.revision <= p_through
    ORDER BY c.revision LIMIT 500;
$$;

CREATE FUNCTION public.vocabulary_purge_ack(
  p_owner_id uuid, p_kind text, p_id uuid, p_parent_id uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  parent uuid;
  list_id uuid;
  identity_purged boolean;
  parent_purged boolean := false;
  list_purged boolean;
  result jsonb;
BEGIN
  IF p_owner_id IS DISTINCT FROM auth.uid() OR auth.uid() IS NULL
    OR p_id IS NULL OR p_kind IS NULL
    OR p_kind NOT IN ('list','concept','variant') THEN RETURN NULL; END IF;
  SELECT i.parent_id INTO parent FROM vocabulary_private.vocabulary_identities i
    WHERE i.owner_id=p_owner_id AND i.kind=p_kind AND i.item_id=p_id AND i.purged;
  identity_purged := FOUND;
  IF p_kind='list' THEN
    IF identity_purged THEN RETURN vocabulary_private.purged_list_tombstone(p_owner_id,p_id); END IF;
    RETURN NULL;
  END IF;

  parent := COALESCE(parent,p_parent_id);
  IF p_kind='concept' THEN
    list_id := parent;
  ELSE
    SELECT i.parent_id INTO list_id FROM vocabulary_private.vocabulary_identities i
      WHERE i.owner_id=p_owner_id AND i.kind='concept' AND i.item_id=parent AND i.purged;
    parent_purged := FOUND;
    IF NOT parent_purged THEN
      SELECT c.list_id INTO list_id FROM public.concepts c
        WHERE c.owner_id=p_owner_id AND c.id=parent;
    END IF;
  END IF;
  list_purged := EXISTS (SELECT 1 FROM vocabulary_private.vocabulary_identities i
    WHERE i.owner_id=p_owner_id AND i.kind='list' AND i.item_id=list_id AND i.purged);
  IF NOT (identity_purged OR parent_purged OR list_purged) THEN RETURN NULL; END IF;

  result := vocabulary_private.purged_child_tombstone(p_kind,p_owner_id,p_id,parent);
  IF list_purged THEN
    result := result || jsonb_build_object('_sync_deleted_list',
      vocabulary_private.purged_list_tombstone(p_owner_id,list_id));
  END IF;
  IF parent_purged THEN
    result := result || jsonb_build_object('_sync_deleted_concept',
      vocabulary_private.purged_child_tombstone('concept',p_owner_id,parent,list_id));
  END IF;
  RETURN result;
END $$;

DROP TRIGGER vocabulary_pull_change ON public.concepts;
CREATE TRIGGER vocabulary_pull_change AFTER INSERT OR UPDATE OR DELETE
  ON public.concepts FOR EACH ROW
  EXECUTE FUNCTION vocabulary_private.record_vocabulary_pull_change();
DROP TRIGGER vocabulary_pull_change ON public.word_variants;
CREATE TRIGGER vocabulary_pull_change AFTER INSERT OR UPDATE OR DELETE
  ON public.word_variants FOR EACH ROW
  EXECUTE FUNCTION vocabulary_private.record_vocabulary_pull_change();

CREATE FUNCTION vocabulary_private.fence_vocabulary_identity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  item_kind text := TG_ARGV[0];
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.owner_id IS DISTINCT FROM OLD.owner_id OR NEW.id IS DISTINCT FROM OLD.id THEN
      RAISE EXCEPTION 'Vocabulary identity is immutable' USING ERRCODE='42501';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_WHEN = 'BEFORE' THEN
    -- Let RLS reject foreign writes without revealing a foreign marker.
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM NEW.owner_id THEN
      RETURN NEW;
    END IF;
    -- Fast path for an already committed purge. The AFTER check covers an
    -- insertion waiting on the vocabulary row's unique index during purge.
    IF EXISTS (SELECT 1 FROM vocabulary_private.vocabulary_identities i
      WHERE i.owner_id=NEW.owner_id AND i.kind=item_kind AND i.item_id=NEW.id AND i.purged)
    THEN RAISE EXCEPTION 'Vocabulary identity was physically removed' USING ERRCODE='PV001'; END IF;
    RETURN NEW;
  END IF;

  -- An actual insert owns the vocabulary row first. A conflicting DELETE
  -- makes the identical identity transition in that row order. A guarded
  -- UPSERT checks the committed marker even if the outer read was earlier.
  INSERT INTO vocabulary_private.vocabulary_identities AS identity(owner_id,kind,item_id)
    VALUES (NEW.owner_id,item_kind,NEW.id)
    ON CONFLICT (owner_id,kind,item_id) DO UPDATE SET purged=false
      WHERE NOT identity.purged;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vocabulary identity was physically removed' USING ERRCODE='PV001';
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION vocabulary_private.fence_vocabulary_identity() FROM PUBLIC, anon, authenticated;

-- AFTER guard sorts before the pull journal, which must not see a replay.
DO $$
DECLARE spec text[];
BEGIN
  FOREACH spec SLICE 1 IN ARRAY ARRAY[
    ARRAY['vocabulary_lists','list'], ARRAY['concepts','concept'], ARRAY['word_variants','variant']
  ] LOOP
    EXECUTE format('CREATE TRIGGER vocabulary_identity_before_insert BEFORE INSERT ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION vocabulary_private.fence_vocabulary_identity(%L)',spec[1],spec[2]);
    EXECUTE format('CREATE TRIGGER vocabulary_identity_after_insert AFTER INSERT ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION vocabulary_private.fence_vocabulary_identity(%L)',spec[1],spec[2]);
    EXECUTE format('CREATE TRIGGER vocabulary_identity_keep BEFORE UPDATE OF owner_id,id ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION vocabulary_private.fence_vocabulary_identity(%L)',spec[1],spec[2]);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.vocabulary_pull_catchup_ready()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT to_regclass('vocabulary_private.pull_watermarks') IS NOT NULL
    AND to_regclass('vocabulary_private.pull_changes') IS NOT NULL
    AND to_regprocedure('public.vocabulary_pull_revision(uuid)') IS NOT NULL
    AND to_regprocedure('public.vocabulary_pull_inventory(uuid,uuid)') IS NOT NULL
    AND to_regprocedure('public.vocabulary_pull_changed_lists(uuid,bigint,bigint)') IS NOT NULL
    AND to_regprocedure('public.vocabulary_pull_changed_progress(uuid,bigint,bigint)') IS NOT NULL
    AND (SELECT count(*) FROM pg_catalog.pg_trigger g
      WHERE g.tgname='vocabulary_pull_change'
        AND g.tgfoid=to_regprocedure('vocabulary_private.record_vocabulary_pull_change()')
        AND g.tgenabled IN ('O','A')
        AND ((g.tgrelid IN (to_regclass('public.vocabulary_lists'),to_regclass('public.concepts'),
                            to_regclass('public.word_variants')) AND g.tgtype=29)
          OR (g.tgrelid=to_regclass('public.variant_progress') AND g.tgtype=21)))=4;
$$;

CREATE FUNCTION public.vocabulary_purge_ready()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.vocabulary_pull_catchup_ready()
    AND to_regclass('vocabulary_private.vocabulary_identities') IS NOT NULL
    AND to_regclass('vocabulary_private.pull_physically_removed_lists') IS NOT NULL
    AND to_regprocedure('public.vocabulary_pull_concepts(uuid,uuid,uuid)') IS NOT NULL
    AND to_regprocedure('public.vocabulary_purge_ack(uuid,text,uuid,uuid)') IS NOT NULL
    AND (SELECT count(*) FROM pg_catalog.pg_trigger g
      WHERE g.tgrelid IN (to_regclass('public.vocabulary_lists'),to_regclass('public.concepts'),
                          to_regclass('public.word_variants'))
        AND g.tgfoid=to_regprocedure('vocabulary_private.fence_vocabulary_identity()')
        AND g.tgenabled IN ('O','A')
        AND ((g.tgname='vocabulary_identity_after_insert' AND g.tgtype=5)
          OR (g.tgname='vocabulary_identity_before_insert' AND g.tgtype=7)
          OR (g.tgname='vocabulary_identity_keep' AND g.tgtype=19)))=9;
$$;

REVOKE ALL ON FUNCTION public.vocabulary_pull_inventory(uuid,uuid),
  public.vocabulary_pull_concepts(uuid,uuid,uuid),
  public.vocabulary_purge_ack(uuid,text,uuid,uuid),
  public.vocabulary_purge_ready() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vocabulary_pull_inventory(uuid,uuid),
  public.vocabulary_pull_concepts(uuid,uuid,uuid),
  public.vocabulary_purge_ack(uuid,text,uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vocabulary_purge_ready() TO anon, authenticated;

-- Adding the inventory on a historical deployment cannot temporarily arm 019
-- before the next migration installs the complete reset contract.
REVOKE ALL ON FUNCTION public.reset_e2e_account(text) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
