BEGIN;

-- Each account has a commit-ordered watermark. Holding its row lock until
-- commit avoids the gap that a standalone PostgreSQL sequence would leave
-- when two transactions receive numbers and commit in the opposite order.
CREATE TABLE vocabulary_private.pull_watermarks (
  owner_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  revision bigint NOT NULL
);
CREATE TABLE vocabulary_private.pull_changes (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('list', 'progress')),
  item_id uuid NOT NULL,
  direction text NOT NULL,
  revision bigint NOT NULL,
  deleted_list boolean NOT NULL,
  PRIMARY KEY (owner_id, kind, item_id, direction)
);
CREATE INDEX pull_changes_window ON vocabulary_private.pull_changes(owner_id, kind, revision);
REVOKE ALL ON vocabulary_private.pull_watermarks, vocabulary_private.pull_changes
  FROM PUBLIC, anon, authenticated;

CREATE FUNCTION vocabulary_private.record_vocabulary_pull_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  owner uuid;
  item uuid;
  item_direction text := '';
  item_kind text := 'list';
  new_revision bigint;
  removed_list boolean := false;
BEGIN
  IF TG_OP = 'UPDATE' AND to_jsonb(NEW) = to_jsonb(OLD) THEN RETURN NULL; END IF;
  IF TG_TABLE_NAME = 'vocabulary_lists' THEN
    IF TG_OP = 'DELETE' THEN
      owner := OLD.owner_id;
      item := OLD.id;
      removed_list := true;
    ELSE
      owner := NEW.owner_id;
      item := NEW.id;
    END IF;
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

  -- An account delete already cascades through vocabulary and these
  -- tables. There is no remaining account to synchronize in that case.
  IF TG_OP = 'DELETE' AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id = owner) THEN
    RETURN NULL;
  END IF;

  INSERT INTO vocabulary_private.pull_watermarks AS watermark(owner_id, revision)
    VALUES (owner, 1)
    ON CONFLICT (owner_id) DO UPDATE SET revision = watermark.revision + 1
    RETURNING revision INTO new_revision;
  INSERT INTO vocabulary_private.pull_changes
    (owner_id, kind, item_id, direction, revision, deleted_list)
    VALUES (owner, item_kind, item, item_direction, new_revision, removed_list)
    ON CONFLICT (owner_id, kind, item_id, direction) DO UPDATE
    SET revision = excluded.revision, deleted_list = excluded.deleted_list;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION vocabulary_private.record_vocabulary_pull_change()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER vocabulary_pull_change AFTER INSERT OR UPDATE OR DELETE
  ON public.vocabulary_lists FOR EACH ROW
  EXECUTE FUNCTION vocabulary_private.record_vocabulary_pull_change();
CREATE TRIGGER vocabulary_pull_change AFTER INSERT OR UPDATE
  ON public.concepts FOR EACH ROW
  EXECUTE FUNCTION vocabulary_private.record_vocabulary_pull_change();
CREATE TRIGGER vocabulary_pull_change AFTER INSERT OR UPDATE
  ON public.word_variants FOR EACH ROW
  EXECUTE FUNCTION vocabulary_private.record_vocabulary_pull_change();
CREATE TRIGGER vocabulary_pull_change AFTER INSERT OR UPDATE
  ON public.variant_progress FOR EACH ROW
  EXECUTE FUNCTION vocabulary_private.record_vocabulary_pull_change();

CREATE FUNCTION public.vocabulary_pull_revision(p_owner_id uuid)
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN p_owner_id = auth.uid() THEN COALESCE(
    (SELECT revision FROM vocabulary_private.pull_watermarks WHERE owner_id = p_owner_id), 0
  ) END;
$$;

CREATE FUNCTION public.vocabulary_pull_changed_lists(
  p_owner_id uuid, p_after bigint, p_through bigint
) RETURNS TABLE (revision bigint, value jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  -- A physical removal needs only a synthetic tombstone. The journal does
  -- not retain a deleted row's title, sharing token or other content.
  SELECT c.revision, COALESCE(to_jsonb(l), jsonb_build_object(
      'id', c.item_id, 'owner_id', c.owner_id, 'is_deleted', true, 'name', '',
      'created_at', '1970-01-01T00:00:00Z', 'updated_at', '1970-01-01T00:00:00Z'))
    FROM vocabulary_private.pull_changes c
    LEFT JOIN public.vocabulary_lists l ON l.owner_id = c.owner_id AND l.id = c.item_id
    WHERE c.owner_id = p_owner_id AND p_owner_id = auth.uid() AND c.kind = 'list'
      AND c.revision > p_after AND c.revision <= p_through
      AND (l.id IS NOT NULL OR c.deleted_list);
$$;

CREATE FUNCTION public.vocabulary_pull_changed_progress(
  p_owner_id uuid, p_after bigint, p_through bigint
) RETURNS TABLE (revision bigint, value jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT c.revision, to_jsonb(p)
    FROM vocabulary_private.pull_changes c
    JOIN public.variant_progress p ON p.user_id = c.owner_id AND p.variant_owner_id = c.owner_id
      AND p.variant_id = c.item_id AND p.direction = c.direction
    WHERE c.owner_id = p_owner_id AND p_owner_id = auth.uid() AND c.kind = 'progress'
      AND c.revision > p_after AND c.revision <= p_through;
$$;

CREATE FUNCTION public.vocabulary_pull_catchup_ready()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT to_regclass('vocabulary_private.pull_watermarks') IS NOT NULL
    AND to_regclass('vocabulary_private.pull_changes') IS NOT NULL
    AND to_regprocedure('public.vocabulary_pull_revision(uuid)') IS NOT NULL
    AND to_regprocedure('public.vocabulary_pull_changed_lists(uuid,bigint,bigint)') IS NOT NULL
    AND to_regprocedure('public.vocabulary_pull_changed_progress(uuid,bigint,bigint)') IS NOT NULL
    AND (
      SELECT count(*) FROM pg_catalog.pg_trigger g
      WHERE g.tgname = 'vocabulary_pull_change'
        AND g.tgfoid = to_regprocedure('vocabulary_private.record_vocabulary_pull_change()')
        AND g.tgenabled IN ('O','A')
        AND ((g.tgrelid = to_regclass('public.vocabulary_lists') AND g.tgtype = 29)
          OR (g.tgrelid IN (to_regclass('public.concepts'), to_regclass('public.word_variants'),
                            to_regclass('public.variant_progress')) AND g.tgtype = 21))
    ) = 4;
$$;

REVOKE ALL ON FUNCTION public.vocabulary_pull_revision(uuid),
  public.vocabulary_pull_changed_lists(uuid,bigint,bigint),
  public.vocabulary_pull_changed_progress(uuid,bigint,bigint),
  public.vocabulary_pull_catchup_ready() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vocabulary_pull_revision(uuid),
  public.vocabulary_pull_changed_lists(uuid,bigint,bigint),
  public.vocabulary_pull_changed_progress(uuid,bigint,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vocabulary_pull_catchup_ready() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
