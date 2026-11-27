-- Disposable server. Exercise the same INSERT ... ON CONFLICT writes as sync.
BEGIN;
INSERT INTO auth.users(id, email) VALUES
  ('14000000-0000-4000-8000-000000000001', 'tombstones@example.test');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '14000000-0000-4000-8000-000000000001', true);

DO $$
DECLARE
  owner uuid := auth.uid();
  deleted_list uuid := '14000000-0000-4000-8000-000000000011';
  live_list uuid := '14000000-0000-4000-8000-000000000012';
  list_child uuid := '14000000-0000-4000-8000-000000000021';
  deleted_concept uuid := '14000000-0000-4000-8000-000000000022';
  live_concept uuid := '14000000-0000-4000-8000-000000000023';
  orphan_concept uuid := '14000000-0000-4000-8000-000000000024';
  list_word uuid := '14000000-0000-4000-8000-000000000031';
  concept_word uuid := '14000000-0000-4000-8000-000000000032';
  deleted_word uuid := '14000000-0000-4000-8000-000000000033';
  list_ack public.vocabulary_lists;
  concept_ack public.concepts;
  word_ack public.word_variants;
BEGIN
  INSERT INTO public.vocabulary_lists(id, owner_id, name)
    VALUES (deleted_list, owner, 'First'), (live_list, owner, 'Second');
  INSERT INTO public.concepts(id, list_id, notes)
    VALUES (list_child, deleted_list, 'Original'), (deleted_concept, live_list, 'Original'),
           (live_concept, live_list, 'Original');
  INSERT INTO public.word_variants(id, concept_id, word, lang_code)
    VALUES (list_word, list_child, 'first', 'en'), (concept_word, deleted_concept, 'second', 'en'),
           (deleted_word, live_concept, 'third', 'en');

  UPDATE public.vocabulary_lists SET is_deleted = true WHERE id = deleted_list;
  UPDATE public.concepts SET is_deleted = true WHERE id = deleted_concept;
  UPDATE public.word_variants SET is_deleted = true WHERE id = deleted_word;

  INSERT INTO public.vocabulary_lists(id, owner_id, name, is_deleted)
    VALUES (deleted_list, owner, 'Stale rename', false)
    ON CONFLICT(owner_id,id) DO UPDATE SET name = excluded.name, is_deleted = excluded.is_deleted
    RETURNING * INTO list_ack;
  IF list_ack.is_deleted IS DISTINCT FROM true OR list_ack.name <> 'First' THEN
    RAISE EXCEPTION 'Stale list upsert overrode its tombstone';
  END IF;

  INSERT INTO public.concepts(id, list_id, notes, is_deleted)
    VALUES (deleted_concept, live_list, 'Stale note', false)
    ON CONFLICT(owner_id,id) DO UPDATE SET notes = excluded.notes, is_deleted = excluded.is_deleted
    RETURNING * INTO concept_ack;
  IF concept_ack.is_deleted IS DISTINCT FROM true OR concept_ack.notes <> 'Original' THEN
    RAISE EXCEPTION 'Stale concept upsert overrode its tombstone';
  END IF;

  UPDATE public.concepts SET notes = 'Stale note', is_deleted = false WHERE id = list_child
    RETURNING * INTO concept_ack;
  IF concept_ack.is_deleted IS DISTINCT FROM true OR concept_ack.notes <> 'Original' THEN
    RAISE EXCEPTION 'A stale concept edit ignored its deleted list';
  END IF;
  INSERT INTO public.concepts(id, list_id) VALUES (orphan_concept, deleted_list)
    RETURNING * INTO concept_ack;
  IF concept_ack.is_deleted IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'A new concept escaped its deleted list';
  END IF;

  FOR word_ack IN
    INSERT INTO public.word_variants(id, concept_id, word, lang_code, is_deleted)
      VALUES (list_word, list_child, 'stale', 'en', false), (concept_word, deleted_concept, 'stale', 'en', false),
             (deleted_word, live_concept, 'stale', 'en', false)
      ON CONFLICT(owner_id,id) DO UPDATE SET word = excluded.word, is_deleted = excluded.is_deleted
      RETURNING *
  LOOP
    IF word_ack.is_deleted IS DISTINCT FROM true OR word_ack.word = 'stale' THEN
      RAISE EXCEPTION 'Stale word edit ignored its tombstone or that of an ancestor';
    END IF;
  END LOOP;

  UPDATE public.concepts SET notes = 'Live edit' WHERE id = live_concept
    RETURNING * INTO concept_ack;
  IF concept_ack.is_deleted IS DISTINCT FROM false OR concept_ack.notes <> 'Live edit' THEN
    RAISE EXCEPTION 'A live concept did not accept an ordinary update';
  END IF;
END $$;

ROLLBACK;
