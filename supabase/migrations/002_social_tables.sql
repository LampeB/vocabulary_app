-- Social fields on profiles (idempotent)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS current_streak      INTEGER      NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS longest_streak      INTEGER      NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_words_mastered INTEGER     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_study_date     DATE,
  ADD COLUMN IF NOT EXISTS is_premium          BOOLEAN      NOT NULL DEFAULT false;

-- ─── Friend requests ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.friend_requests (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id  UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  to_user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status        TEXT        NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending','accepted','declined')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (from_user_id, to_user_id)
);

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "View own requests"
  ON public.friend_requests FOR SELECT
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

CREATE POLICY "Send friend request"
  ON public.friend_requests FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Recipient can update status"
  ON public.friend_requests FOR UPDATE
  USING (auth.uid() = to_user_id);

-- ─── Friendships ──────────────────────────────────────────────────────────────
-- user_a_id < user_b_id (lexicographic) enforced by app to prevent duplicates
CREATE TABLE IF NOT EXISTS public.friendships (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_b_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_a_id, user_b_id)
);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "View own friendships"
  ON public.friendships FOR SELECT
  USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);

CREATE POLICY "Create friendship"
  ON public.friendships FOR INSERT
  WITH CHECK (auth.uid() = user_a_id OR auth.uid() = user_b_id);

CREATE POLICY "Remove friendship"
  ON public.friendships FOR DELETE
  USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);
