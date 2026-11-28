-- Disposable database only. Run with the migration's real privileges and RLS.
BEGIN;
INSERT INTO auth.users(id,email) VALUES
  ('19000000-0000-4000-8000-000000000001','challenge-actor@example.invalid'),
  ('19000000-0000-4000-8000-000000000002','challenge-foreign@example.invalid'),
  ('19000000-0000-4000-8000-000000000003','challenge-friend@example.invalid');
INSERT INTO public.vocabulary_lists(owner_id,id,name,visibility,is_deleted) VALUES
  ('19000000-0000-4000-8000-000000000002','19000000-0000-4000-8000-000000000011','Hidden','private',false),
  ('19000000-0000-4000-8000-000000000003','19000000-0000-4000-8000-000000000011','Historical','private',false),
  ('19000000-0000-4000-8000-000000000002','19000000-0000-4000-8000-000000000012','Deleted','public',true),
  ('19000000-0000-4000-8000-000000000002','19000000-0000-4000-8000-000000000013','Public','public',false),
  ('19000000-0000-4000-8000-000000000003','19000000-0000-4000-8000-000000000013','Collision','private',false),
  ('19000000-0000-4000-8000-000000000001','19000000-0000-4000-8000-000000000014','Owned','private',false),
  ('19000000-0000-4000-8000-000000000003','19000000-0000-4000-8000-000000000015','Friends','friends',false);
INSERT INTO public.friendships(user_a_id,user_b_id,consent_verified) VALUES
  ('19000000-0000-4000-8000-000000000001','19000000-0000-4000-8000-000000000003',true);
-- A former participant's challenge may still refer to its original list.
INSERT INTO public.challenges(id,challenger_id,challenged_id,list_owner_id,list_id) VALUES
  ('19000000-0000-4000-8000-000000000021','19000000-0000-4000-8000-000000000003',
   '19000000-0000-4000-8000-000000000001','19000000-0000-4000-8000-000000000003',
   '19000000-0000-4000-8000-000000000011');

SELECT set_config('request.jwt.claim.sub','19000000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  foreign_owner uuid := '19000000-0000-4000-8000-000000000002';
  friend uuid := '19000000-0000-4000-8000-000000000003';
  historical uuid := '19000000-0000-4000-8000-000000000021';
  new_challenge uuid;
  probed uuid;
  qualification uuid;
  resolved_owner uuid;
BEGIN
  INSERT INTO public.challenges(challenger_id,challenged_id) VALUES(auth.uid(),friend)
    RETURNING id INTO new_challenge;
  FOREACH probed IN ARRAY ARRAY[
    '19000000-0000-4000-8000-000000000011'::uuid, -- private
    '19000000-0000-4000-8000-000000000012'::uuid, -- tombstone
    '19000000-0000-4000-8000-000000000019'::uuid  -- absent
  ] LOOP
    FOREACH qualification IN ARRAY ARRAY[foreign_owner,NULL::uuid] LOOP
      BEGIN
        INSERT INTO public.challenges(challenger_id,challenged_id,list_id,list_owner_id)
          VALUES(auth.uid(),friend,probed,qualification);
        RAISE EXCEPTION 'Inaccessible challenge list accepted on insert';
      EXCEPTION WHEN insufficient_privilege THEN
        IF SQLERRM <> 'Challenge list unavailable' THEN RAISE; END IF;
      END;
      BEGIN
        UPDATE public.challenges SET list_id=probed,list_owner_id=qualification WHERE id=new_challenge;
        RAISE EXCEPTION 'Inaccessible challenge list accepted on update';
      EXCEPTION WHEN insufficient_privilege THEN
        IF SQLERRM <> 'Challenge list unavailable' THEN RAISE; END IF;
      END;
    END LOOP;
  END LOOP;
  UPDATE public.challenges SET list_id='19000000-0000-4000-8000-000000000013'
    WHERE id=new_challenge RETURNING list_owner_id INTO resolved_owner;
  IF resolved_owner IS DISTINCT FROM foreign_owner THEN
    RAISE EXCEPTION 'Private collision changed public owner resolution';
  END IF;
  INSERT INTO public.challenges(challenger_id,challenged_id,list_id)
    VALUES(auth.uid(),friend,'19000000-0000-4000-8000-000000000014')
    RETURNING list_owner_id INTO resolved_owner;
  IF resolved_owner IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Own list did not resolve'; END IF;
  UPDATE public.challenges SET list_id='19000000-0000-4000-8000-000000000015',list_owner_id=friend
    WHERE id=new_challenge RETURNING list_owner_id INTO resolved_owner;
  IF resolved_owner IS DISTINCT FROM friend THEN RAISE EXCEPTION 'Friend list did not resolve'; END IF;

  UPDATE public.challenges SET challenged_score=10 WHERE id=historical;
  IF NOT FOUND THEN RAISE EXCEPTION 'Existing challenge history is no longer writable'; END IF;
  BEGIN
    UPDATE public.challenges SET challenger_id=foreign_owner WHERE id=historical;
    RAISE EXCEPTION 'Hidden historical reference was shared with a different participant';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'Challenge list unavailable' THEN RAISE; END IF;
  END;
END $$;
ROLLBACK;
