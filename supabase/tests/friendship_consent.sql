-- Disposable database. Real role, RLS, request and challenge boundaries.
BEGIN;
INSERT INTO auth.users(id,email) VALUES
  ('21000000-0000-4000-8000-000000000001','consent-sender@example.invalid'),
  ('21000000-0000-4000-8000-000000000002','consent-recipient@example.invalid'),
  ('21000000-0000-4000-8000-000000000003','consent-stranger@example.invalid');
INSERT INTO public.vocabulary_lists(owner_id,id,name,visibility) VALUES
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000011','Friends list','friends'),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000012','Deleted list','friends'),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000013','Private list','private'),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000014','Public list','public'),
  ('21000000-0000-4000-8000-000000000003','21000000-0000-4000-8000-000000000011','Colliding list','private');
INSERT INTO public.concepts(owner_id,id,list_id,notes) VALUES
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000031','21000000-0000-4000-8000-000000000011','friend'),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000032','21000000-0000-4000-8000-000000000011','deleted concept'),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000033','21000000-0000-4000-8000-000000000012','under deleted list'),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000034','21000000-0000-4000-8000-000000000013','private'),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000035','21000000-0000-4000-8000-000000000014','public'),
  ('21000000-0000-4000-8000-000000000003','21000000-0000-4000-8000-000000000031','21000000-0000-4000-8000-000000000011','colliding private');
INSERT INTO public.word_variants(owner_id,id,concept_id,word,lang_code,is_deleted) VALUES
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000041','21000000-0000-4000-8000-000000000031','friend','fr',false),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000042','21000000-0000-4000-8000-000000000031','deleted variant','ko',true),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000043','21000000-0000-4000-8000-000000000032','under deleted concept','fr',false),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000044','21000000-0000-4000-8000-000000000033','under deleted list','fr',false),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000045','21000000-0000-4000-8000-000000000034','private','fr',false),
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000046','21000000-0000-4000-8000-000000000035','public','fr',false),
  ('21000000-0000-4000-8000-000000000003','21000000-0000-4000-8000-000000000041','21000000-0000-4000-8000-000000000031','colliding private','fr',false);

-- Deleting the parent leaves previously written child rows active in storage.
UPDATE public.concepts SET is_deleted=true
  WHERE owner_id='21000000-0000-4000-8000-000000000002' AND notes='deleted concept';
UPDATE public.vocabulary_lists SET is_deleted=true
  WHERE owner_id='21000000-0000-4000-8000-000000000002' AND name='Deleted list';

CREATE FUNCTION pg_temp.assert_visible_content(expected text[])
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE
  visible_concepts text[];
  visible_variants text[];
BEGIN
  -- Exercise direct child reads as well as the parent-list checks below.
  SELECT ARRAY(SELECT notes FROM public.concepts
    WHERE owner_id IN ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000003')
      AND owner_id IS DISTINCT FROM auth.uid() ORDER BY notes) INTO visible_concepts;
  SELECT ARRAY(SELECT word FROM public.word_variants
    WHERE owner_id IN ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000003')
      AND owner_id IS DISTINCT FROM auth.uid() ORDER BY word) INTO visible_variants;
  IF visible_concepts IS DISTINCT FROM expected OR visible_variants IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'Expected % from other owners; saw concepts % and variants %',
      expected, visible_concepts, visible_variants;
  END IF;
END $$;

-- A pre-migration edge and its request could have been forged unilaterally.
INSERT INTO public.friendships(user_a_id,user_b_id) VALUES
  ('21000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000002');
INSERT INTO public.friend_requests(id,from_user_id,to_user_id,status) VALUES
  ('21000000-0000-4000-8000-000000000021','21000000-0000-4000-8000-000000000001',
   '21000000-0000-4000-8000-000000000002','accepted'),
  ('21000000-0000-4000-8000-000000000022','21000000-0000-4000-8000-000000000001',
   '21000000-0000-4000-8000-000000000002','pending');

-- Model installations granting table-level SELECT to anon. RLS still denies
-- direct access to all content with no authenticated session.
GRANT SELECT ON public.concepts, public.word_variants TO anon;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub','',true);
SELECT pg_temp.assert_visible_content(ARRAY[]::text[]);

SELECT set_config('request.jwt.claim.sub','21000000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  recipient uuid := '21000000-0000-4000-8000-000000000002';
  target_list uuid := '21000000-0000-4000-8000-000000000011';
  request_id uuid;
BEGIN
  BEGIN
    INSERT INTO public.friendships(user_a_id,user_b_id,consent_verified)
      VALUES (recipient,auth.uid(),true);
    RAISE EXCEPTION 'Unilateral friendship accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.friendships SET consent_verified=true WHERE user_a_id=auth.uid();
    RAISE EXCEPTION 'Client promoted a historical friendship';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.friend_requests(from_user_id,to_user_id,status,sender_verified)
      VALUES (auth.uid(),recipient,'accepted',true);
    RAISE EXCEPTION 'Client fabricated an accepted request';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  IF EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE id=target_list) THEN
    RAISE EXCEPTION 'Unverified friendship exposed the friends list';
  END IF;
  PERFORM pg_temp.assert_visible_content(ARRAY['public']);
  BEGIN
    INSERT INTO public.challenges(challenger_id,challenged_id,list_id,list_owner_id)
      VALUES(auth.uid(),recipient,target_list,recipient);
    RAISE EXCEPTION 'Unverified friendship permitted a challenge on a friends list';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'Challenge list unavailable' THEN RAISE; END IF;
  END;
  PERFORM public.send_friend_request(recipient);
  PERFORM public.send_friend_request(recipient);
  SELECT id INTO STRICT request_id FROM public.friend_requests
    WHERE to_user_id=recipient AND status='pending' AND sender_verified;
  BEGIN
    PERFORM public.respond_friend_request(request_id,true);
    RAISE EXCEPTION 'Sender answered their own request';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  IF EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE id=target_list) THEN
    RAISE EXCEPTION 'Pending request exposed the friends list';
  END IF;
  PERFORM pg_temp.assert_visible_content(ARRAY['public']);
END $$;

SELECT set_config('request.jwt.claim.sub','21000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE request_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.vocabulary_lists
      WHERE owner_id=auth.uid() AND name='Deleted list' AND is_deleted)
    OR NOT EXISTS (SELECT 1 FROM public.concepts
      WHERE owner_id=auth.uid() AND notes='deleted concept' AND is_deleted)
    OR NOT EXISTS (SELECT 1 FROM public.word_variants
      WHERE owner_id=auth.uid() AND word='deleted variant' AND is_deleted) THEN
    RAISE EXCEPTION 'Owner lost access to tombstones needed for sync';
  END IF;
  PERFORM public.send_friend_request('21000000-0000-4000-8000-000000000001');
  IF EXISTS (SELECT 1 FROM public.friend_requests WHERE from_user_id=auth.uid() AND sender_verified) THEN
    RAISE EXCEPTION 'Reciprocal send created a second pending request';
  END IF;
  BEGIN
    PERFORM public.respond_friend_request('21000000-0000-4000-8000-000000000022',true);
    RAISE EXCEPTION 'Recipient legitimized an unverified historical request';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  SELECT id INTO STRICT request_id FROM public.friend_requests
    WHERE to_user_id=auth.uid() AND status='pending' AND sender_verified;
  BEGIN
    UPDATE public.friend_requests SET from_user_id='21000000-0000-4000-8000-000000000003',
      status='accepted' WHERE id=request_id;
    RAISE EXCEPTION 'Recipient forged a change of sender';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM public.respond_friend_request(request_id,true);
  PERFORM public.respond_friend_request(request_id,true);
END $$;

SELECT set_config('request.jwt.claim.sub','21000000-0000-4000-8000-000000000003',true);
SELECT pg_temp.assert_visible_content(ARRAY['public']);

SELECT set_config('request.jwt.claim.sub','21000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE
  recipient uuid := '21000000-0000-4000-8000-000000000002';
  target_list uuid := '21000000-0000-4000-8000-000000000011';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE id=target_list) THEN
    RAISE EXCEPTION 'Recipient consent did not permit friends-list access';
  END IF;
  PERFORM pg_temp.assert_visible_content(ARRAY['friend','public']);
  UPDATE public.concepts SET notes='unauthorized edit' WHERE owner_id=recipient AND notes='friend';
  IF FOUND THEN RAISE EXCEPTION 'Friendship granted a concept write'; END IF;
  UPDATE public.word_variants SET word='unauthorized edit' WHERE owner_id=recipient AND word='friend';
  IF FOUND THEN RAISE EXCEPTION 'Friendship granted a variant write'; END IF;
  INSERT INTO public.challenges(challenger_id,challenged_id,list_id)
    VALUES(auth.uid(),recipient,target_list);
  DELETE FROM public.friendships WHERE user_b_id=recipient;
  IF NOT FOUND THEN RAISE EXCEPTION 'Friend could not withdraw access'; END IF;
  IF EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE id=target_list) THEN
    RAISE EXCEPTION 'Removing friendship did not withdraw access';
  END IF;
  PERFORM pg_temp.assert_visible_content(ARRAY['public']);
  PERFORM public.send_friend_request(recipient);
END $$;

SELECT set_config('request.jwt.claim.sub','21000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE
  previous_request uuid;
  new_request uuid;
BEGIN
  SELECT id INTO STRICT previous_request FROM public.friend_requests
    WHERE to_user_id=auth.uid() AND status='accepted' AND sender_verified;
  SELECT id INTO STRICT new_request FROM public.friend_requests
    WHERE to_user_id=auth.uid() AND status='pending' AND sender_verified;
  PERFORM public.respond_friend_request(previous_request,true);
  IF EXISTS (SELECT 1 FROM public.friendships WHERE consent_verified) THEN
    RAISE EXCEPTION 'Old acceptance replay restored a removed friendship';
  END IF;
  PERFORM public.respond_friend_request(new_request,false);
  IF EXISTS (SELECT 1 FROM public.friendships WHERE consent_verified)
    OR NOT EXISTS (SELECT 1 FROM public.friend_requests WHERE id=new_request AND status='declined') THEN
    RAISE EXCEPTION 'Declined request granted friendship access';
  END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','21000000-0000-4000-8000-000000000001',true);
SELECT pg_temp.assert_visible_content(ARRAY['public']);
ROLLBACK;
