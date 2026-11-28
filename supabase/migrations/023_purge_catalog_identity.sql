BEGIN;

ALTER TABLE vocabulary_private.vocabulary_identities
  ADD COLUMN catalog_identity jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Seed provenance is a catalogue key, an origin and two language codes.
-- Retain only bounded identifier shapes on labelled starter rows.
CREATE FUNCTION vocabulary_private.starter_list_identity(p_list public.vocabulary_lists)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT CASE WHEN (p_list).origin='starter'
    AND (p_list).lang_a ~ '^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,2}$'
    AND (p_list).lang_b ~ '^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,2}$'
    AND split_part((p_list).seed_id,':',1) ~ '^starter-[a-z0-9-]{1,80}$'
    AND (p_list).seed_id=split_part((p_list).seed_id,':',1)
      || ':' || (p_list).lang_a || '>' || (p_list).lang_b
    THEN jsonb_build_object('origin','starter','seed_id',(p_list).seed_id,
                           'lang_a',(p_list).lang_a,'lang_b',(p_list).lang_b)
    ELSE '{}'::jsonb END;
$$;
REVOKE ALL ON FUNCTION vocabulary_private.starter_list_identity(public.vocabulary_lists)
  FROM PUBLIC, anon, authenticated;

CREATE FUNCTION vocabulary_private.capture_purged_catalog_identity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  catalogue jsonb;
BEGIN
  CASE TG_ARGV[0]
    WHEN 'list' THEN
      catalogue := vocabulary_private.starter_list_identity(OLD);
    WHEN 'concept' THEN
      SELECT jsonb_build_object('seed_id',OLD.seed_id) INTO catalogue
      FROM public.vocabulary_lists l
      WHERE l.owner_id=OLD.owner_id AND l.id=OLD.list_id
        AND OLD.seed_id ~ '^[a-z0-9][a-z0-9-]{0,95}$'
        AND vocabulary_private.starter_list_identity(l) <> '{}'::jsonb;
    WHEN 'variant' THEN
      SELECT jsonb_build_object('lang_code',OLD.lang_code) INTO catalogue
      FROM public.concepts c JOIN public.vocabulary_lists l
        ON l.owner_id=c.owner_id AND l.id=c.list_id
      WHERE c.owner_id=OLD.owner_id AND c.id=OLD.concept_id
        AND c.seed_id ~ '^[a-z0-9][a-z0-9-]{0,95}$'
        AND OLD.lang_code IN (l.lang_a,l.lang_b)
        AND vocabulary_private.starter_list_identity(l) <> '{}'::jsonb;
  END CASE;

  -- A cascade can already have removed the parent. In that case its
  -- tombstone seals the whole branch and needs no children's catalogue keys.
  IF catalogue IS NOT NULL AND catalogue <> '{}'::jsonb THEN
    UPDATE vocabulary_private.vocabulary_identities
      SET catalog_identity=catalogue
      WHERE owner_id=OLD.owner_id AND kind=TG_ARGV[0] AND item_id=OLD.id AND purged;
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION vocabulary_private.capture_purged_catalog_identity()
  FROM PUBLIC, anon, authenticated;

-- PostgreSQL runs same-event triggers in name order. The purge journal
-- creates the identity before this trigger attaches its catalogue keys.
CREATE TRIGGER zz_vocabulary_purge_catalog AFTER DELETE ON public.vocabulary_lists
  FOR EACH ROW EXECUTE FUNCTION vocabulary_private.capture_purged_catalog_identity('list');
CREATE TRIGGER zz_vocabulary_purge_catalog AFTER DELETE ON public.concepts
  FOR EACH ROW EXECUTE FUNCTION vocabulary_private.capture_purged_catalog_identity('concept');
CREATE TRIGGER zz_vocabulary_purge_catalog AFTER DELETE ON public.word_variants
  FOR EACH ROW EXECUTE FUNCTION vocabulary_private.capture_purged_catalog_identity('variant');

CREATE OR REPLACE FUNCTION vocabulary_private.purged_list_tombstone(p_owner_id uuid, p_list_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'id', p_list_id, 'owner_id', p_owner_id, 'is_deleted', true, 'name', '',
    'created_at', '1970-01-01T00:00:00Z', 'updated_at', '1970-01-01T00:00:00Z')
    || COALESCE((SELECT i.catalog_identity FROM vocabulary_private.vocabulary_identities i
      WHERE i.owner_id=p_owner_id AND i.kind='list' AND i.item_id=p_list_id AND i.purged), '{}'::jsonb);
$$;

CREATE OR REPLACE FUNCTION vocabulary_private.purged_child_tombstone(
  p_kind text, p_owner_id uuid, p_id uuid, p_parent_id uuid
) RETURNS jsonb LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'id', p_id, 'owner_id', p_owner_id, 'is_deleted', true,
    'created_at', '1970-01-01T00:00:00Z', 'updated_at', '1970-01-01T00:00:00Z')
    || CASE WHEN p_kind='concept'
      THEN jsonb_build_object('list_id',p_parent_id,'word_variants','[]'::jsonb)
      ELSE jsonb_build_object('concept_id',p_parent_id) END
    || COALESCE((SELECT i.catalog_identity FROM vocabulary_private.vocabulary_identities i
      WHERE i.owner_id=p_owner_id AND i.kind=p_kind AND i.item_id=p_id AND i.purged), '{}'::jsonb);
$$;

CREATE FUNCTION public.vocabulary_purge_catalog_ready()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.vocabulary_purge_ready()
    AND EXISTS (SELECT 1 FROM pg_catalog.pg_attribute
      WHERE attrelid=to_regclass('vocabulary_private.vocabulary_identities')
        AND attname='catalog_identity' AND attnotnull AND NOT attisdropped)
    AND (SELECT count(*) FROM pg_catalog.pg_trigger
      WHERE tgrelid IN (to_regclass('public.vocabulary_lists'),to_regclass('public.concepts'),
                        to_regclass('public.word_variants'))
        AND tgname='zz_vocabulary_purge_catalog' AND tgtype=9 AND tgenabled IN ('O','A')
        AND tgfoid=to_regprocedure('vocabulary_private.capture_purged_catalog_identity()'))=3;
$$;
REVOKE ALL ON FUNCTION public.vocabulary_purge_catalog_ready() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vocabulary_purge_catalog_ready() TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.reset_e2e_account(text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
