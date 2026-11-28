BEGIN;

-- A timed-out HTTP request can still reach PostgreSQL. Keep each installation's
-- largest applied sequence per logical row, even when other installations edit
-- it in between. The keyed UPSERT and the content write share one transaction.
CREATE SCHEMA vocabulary_private;
REVOKE ALL ON SCHEMA vocabulary_private FROM PUBLIC, anon, authenticated;
CREATE TABLE vocabulary_private.applied_writes (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  relation text NOT NULL,
  row_key text NOT NULL,
  writer uuid NOT NULL,
  sequence bigint NOT NULL CHECK (sequence > 0),
  PRIMARY KEY (owner_id, relation, row_key, writer)
);
REVOKE ALL ON vocabulary_private.applied_writes FROM PUBLIC, anon, authenticated;

CREATE FUNCTION vocabulary_private.keep_vocabulary_write_order()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor uuid := auth.uid();
  body jsonb := to_jsonb(NEW);
  headers jsonb;
  row_owner uuid;
  write_row_key text;
  write_client uuid;
  write_sequence bigint;
BEGIN
  -- Database migrations and service-role-only audio updates do not come from
  -- an authenticated REST user. Normal RLS still governs those operations.
  IF NULLIF(current_setting('request.method', true), '') IS NULL OR actor IS NULL THEN
    RETURN NEW;
  END IF;
  headers := NULLIF(current_setting('request.headers', true), '')::jsonb;
  write_client := (headers->>'x-ponderin-sync-writer')::uuid;
  write_sequence := (headers->>'x-ponderin-sync-sequence')::bigint;
  IF write_client IS NULL OR write_sequence IS NULL OR write_sequence <= 0 THEN
    RAISE EXCEPTION 'Versioned vocabulary writes are required' USING ERRCODE = '42501';
  END IF;

  row_owner := (CASE WHEN TG_TABLE_NAME IN ('variant_progress', 'review_events')
    THEN body->>'user_id' ELSE body->>'owner_id' END)::uuid;
  IF row_owner IS DISTINCT FROM actor THEN
    RAISE EXCEPTION 'Vocabulary owner does not match authenticated user'
      USING ERRCODE = '42501';
  END IF;
  write_row_key := CASE WHEN TG_TABLE_NAME = 'variant_progress'
    THEN jsonb_build_array(body->>'variant_owner_id', body->>'variant_id', body->>'direction')::text
    ELSE body->>'id' END;

  INSERT INTO vocabulary_private.applied_writes AS applied
    (owner_id, relation, row_key, writer, sequence)
  VALUES (actor, TG_TABLE_NAME, write_row_key, write_client, write_sequence)
  ON CONFLICT (owner_id, relation, row_key, writer) DO UPDATE
    SET sequence = excluded.sequence
    WHERE applied.sequence < excluded.sequence;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'This vocabulary write is older than the accepted revision'
      USING ERRCODE = '40001';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION vocabulary_private.keep_vocabulary_write_order()
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE relation_name text;
BEGIN
  FOREACH relation_name IN ARRAY ARRAY[
    'vocabulary_lists', 'concepts', 'word_variants', 'variant_progress', 'review_events'
  ] LOOP
    -- New clients send this column in every mutation. A server without the
    -- fenced protocol rejects the write rather than silently applying it.
    EXECUTE format(
      'ALTER TABLE public.%I ADD COLUMN sync_write_protocol smallint NOT NULL DEFAULT 16 CHECK (sync_write_protocol = 16)',
      relation_name
    );
    -- AFTER INSERT runs only for actual inserts, not the INSERT half of an
    -- UPSERT that hit a conflict. The UPDATE path consumes the sequence once.
    EXECUTE format(
      'CREATE TRIGGER zz_vocabulary_write_order_insert AFTER INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION vocabulary_private.keep_vocabulary_write_order()',
      relation_name
    );
    EXECUTE format(
      'CREATE TRIGGER zz_vocabulary_write_order_update BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION vocabulary_private.keep_vocabulary_write_order()',
      relation_name
    );
  END LOOP;
END $$;

CREATE FUNCTION public.vocabulary_sync_write_ready()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT to_regclass('vocabulary_private.applied_writes') IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM unnest(ARRAY['vocabulary_lists', 'concepts',
        'word_variants', 'variant_progress', 'review_events']) AS relation_name
      WHERE NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_attribute AS attr
        WHERE attr.attrelid = to_regclass('public.' || relation_name)
          AND attr.attname = 'sync_write_protocol' AND NOT attr.attisdropped
      ) OR (
        SELECT count(*) FROM pg_catalog.pg_trigger AS trigger
        WHERE trigger.tgrelid = to_regclass('public.' || relation_name)
          AND trigger.tgfoid = to_regprocedure('vocabulary_private.keep_vocabulary_write_order()')
          AND trigger.tgenabled IN ('O', 'A')
          AND ((trigger.tgname = 'zz_vocabulary_write_order_insert' AND trigger.tgtype = 5)
            OR (trigger.tgname = 'zz_vocabulary_write_order_update' AND trigger.tgtype = 19))
      ) <> 2
    );
$$;
REVOKE ALL ON FUNCTION public.vocabulary_sync_write_ready() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.vocabulary_sync_write_ready() TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
