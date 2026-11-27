-- Disposable database. Real role, RLS, request and challenge boundaries.
BEGIN;
INSERT INTO auth.users(id,email) VALUES
  ('21000000-0000-4000-8000-000000000001','consent-sender@example.invalid'),
  ('21000000-0000-4000-8000-000000000002','consent-recipient@example.invalid'),
  ('21000000-0000-4000-8000-000000000003','consent-stranger@example.invalid');
INSERT INTO public.vocabulary_lists(owner_id,id,name,visibility) VALUES
  ('21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000011','Friends list','friends');
-- A pre-migration edge and its request could have been forged unilaterally.
INSERT INTO public.friendships(user_a_id,user_b_id) VALUES
  ('21000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000002');
INSERT INTO public.friend_requests(id,from_user_id,to_user_id,status) VALUES
  ('21000000-0000-4000-8000-000000000021','21000000-0000-4000-8000-000000000001',
   '21000000-0000-4000-8000-000000000002','accepted'),
  ('21000000-0000-4000-8000-000000000022','21000000-0000-4000-8000-000000000001',
   '21000000-0000-4000-8000-000000000002','pending');

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
END $$;

SELECT set_config('request.jwt.claim.sub','21000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE request_id uuid;
BEGIN
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

SELECT set_config('request.jwt.claim.sub','21000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE
  recipient uuid := '21000000-0000-4000-8000-000000000002';
  target_list uuid := '21000000-0000-4000-8000-000000000011';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE id=target_list) THEN
    RAISE EXCEPTION 'Recipient consent did not permit friends-list access';
  END IF;
  INSERT INTO public.challenges(challenger_id,challenged_id,list_id)
    VALUES(auth.uid(),recipient,target_list);
  DELETE FROM public.friendships WHERE user_b_id=recipient;
  IF NOT FOUND THEN RAISE EXCEPTION 'Friend could not withdraw access'; END IF;
  IF EXISTS (SELECT 1 FROM public.vocabulary_lists WHERE id=target_list) THEN
    RAISE EXCEPTION 'Removing friendship did not withdraw access';
  END IF;
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
ROLLBACK;
