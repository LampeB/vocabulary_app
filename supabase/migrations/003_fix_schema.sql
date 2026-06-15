-- Idempotent fix: renames old column names to what the app expects,
-- fixes the lists_friends policy, and adds the profile creation trigger.
-- Safe to run on a fresh project (no-ops if columns already have the right names).

DO $$
BEGIN

  -- ── friend_requests: from_user → from_user_id ──────────────────────────────
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'friend_requests'
      AND column_name  = 'from_user'
  ) THEN
    ALTER TABLE public.friend_requests RENAME COLUMN from_user TO from_user_id;
  END IF;

  -- ── friend_requests: to_user → to_user_id ──────────────────────────────────
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'friend_requests'
      AND column_name  = 'to_user'
  ) THEN
    ALTER TABLE public.friend_requests RENAME COLUMN to_user TO to_user_id;
  END IF;

  -- ── friendships: user_a → user_a_id ────────────────────────────────────────
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'friendships'
      AND column_name  = 'user_a'
  ) THEN
    ALTER TABLE public.friendships RENAME COLUMN user_a TO user_a_id;
  END IF;

  -- ── friendships: user_b → user_b_id ────────────────────────────────────────
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'friendships'
      AND column_name  = 'user_b'
  ) THEN
    ALTER TABLE public.friendships RENAME COLUMN user_b TO user_b_id;
  END IF;

END $$;

-- ── Fix lists_friends RLS policy ──────────────────────────────────────────────
DROP POLICY IF EXISTS "lists_friends" ON public.vocabulary_lists;
CREATE POLICY "lists_friends" ON public.vocabulary_lists FOR SELECT USING (
  visibility = 'friends' AND EXISTS (
    SELECT 1 FROM public.friendships
    WHERE (user_a_id = auth.uid() AND user_b_id = owner_id)
       OR (user_b_id = auth.uid() AND user_a_id = owner_id)
  )
);

-- ── Drop old friend_requests policies (001 names) and recreate ────────────────
DROP POLICY IF EXISTS "friend_requests_own" ON public.friend_requests;
DROP POLICY IF EXISTS "View own requests"   ON public.friend_requests;
DROP POLICY IF EXISTS "Send friend request" ON public.friend_requests;
DROP POLICY IF EXISTS "Recipient can update status" ON public.friend_requests;

CREATE POLICY "View own requests"
  ON public.friend_requests FOR SELECT
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

CREATE POLICY "Send friend request"
  ON public.friend_requests FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Recipient can update status"
  ON public.friend_requests FOR UPDATE
  USING (auth.uid() = to_user_id);

-- ── Drop old friendships policies (001 names) and recreate ───────────────────
DROP POLICY IF EXISTS "friendships_own"    ON public.friendships;
DROP POLICY IF EXISTS "View own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Create friendship"  ON public.friendships;
DROP POLICY IF EXISTS "Remove friendship"  ON public.friendships;

CREATE POLICY "View own friendships"
  ON public.friendships FOR SELECT
  USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);

CREATE POLICY "Create friendship"
  ON public.friendships FOR INSERT
  WITH CHECK (auth.uid() = user_a_id OR auth.uid() = user_b_id);

CREATE POLICY "Remove friendship"
  ON public.friendships FOR DELETE
  USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);

-- ── Profile auto-creation trigger ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
