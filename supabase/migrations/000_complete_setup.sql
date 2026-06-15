-- Complete VocabKR schema setup.
-- Run this on a fresh Supabase project. Safe to re-run (IF NOT EXISTS everywhere).

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── PROFILES ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id                   UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username             TEXT        UNIQUE NOT NULL CHECK (length(username) >= 3),
  display_name         TEXT,
  avatar_url           TEXT,
  bio                  TEXT,
  total_words_mastered INT         NOT NULL DEFAULT 0,
  current_streak       INT         NOT NULL DEFAULT 0,
  longest_streak       INT         NOT NULL DEFAULT 0,
  last_study_date      DATE,
  is_premium           BOOL        NOT NULL DEFAULT FALSE,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select_own"    ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"    ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own"    ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_public" ON public.profiles;
CREATE POLICY "profiles_select_own"    ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_update_own"    ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own"    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_select_public" ON public.profiles FOR SELECT USING (TRUE);

-- ─── SUBSCRIPTIONS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        REFERENCES auth.users(id) ON DELETE CASCADE,
  rc_customer_id TEXT        UNIQUE,
  tier           TEXT        DEFAULT 'free' CHECK (tier IN ('free','premium','premium_annual')),
  status         TEXT        DEFAULT 'active' CHECK (status IN ('active','expired','cancelled')),
  expires_at     TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "subscriptions_own" ON public.subscriptions;
CREATE POLICY "subscriptions_own" ON public.subscriptions USING (user_id = auth.uid());

-- ─── VOCABULARY LISTS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.vocabulary_lists (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    UUID        REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL,
  description TEXT,
  visibility  TEXT        DEFAULT 'private' CHECK (visibility IN ('private','friends','public')),
  word_count  INT         DEFAULT 0,
  share_token TEXT        UNIQUE,
  is_deleted  BOOL        DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.vocabulary_lists ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_vocabulary_lists_owner  ON public.vocabulary_lists (owner_id);
CREATE INDEX IF NOT EXISTS idx_vocabulary_lists_token  ON public.vocabulary_lists (share_token);

-- ─── CONCEPTS ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.concepts (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id    UUID        REFERENCES public.vocabulary_lists(id) ON DELETE CASCADE,
  category   TEXT,
  notes      TEXT,
  image_url  TEXT,
  example_fr TEXT,
  example_ko TEXT,
  is_deleted BOOL        DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.concepts ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_concepts_list ON public.concepts (list_id);

-- ─── WORD VARIANTS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.word_variants (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_id     UUID        REFERENCES public.concepts(id) ON DELETE CASCADE,
  word           TEXT        NOT NULL,
  lang_code      TEXT        NOT NULL CHECK (lang_code IN ('fr','ko')),
  register_tag   TEXT        DEFAULT 'neutral',
  context_tags   JSONB       DEFAULT '[]',
  is_primary     BOOL        DEFAULT FALSE,
  audio_hash     TEXT,
  audio_voice_id TEXT,
  position       INT         DEFAULT 0,
  is_deleted     BOOL        DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.word_variants ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_word_variants_concept  ON public.word_variants (concept_id, lang_code);
CREATE INDEX IF NOT EXISTS idx_word_variants_audio    ON public.word_variants (audio_hash);

-- ─── VARIANT PROGRESS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.variant_progress (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        REFERENCES auth.users(id) ON DELETE CASCADE,
  variant_id     UUID        REFERENCES public.word_variants(id) ON DELETE CASCADE,
  direction      TEXT        NOT NULL CHECK (direction IN ('frToKo','koToFr')),
  stability      REAL        DEFAULT 0,
  difficulty     REAL        DEFAULT 5,
  elapsed_days   INT         DEFAULT 0,
  scheduled_days INT         DEFAULT 0,
  reps           INT         DEFAULT 0,
  lapses         INT         DEFAULT 0,
  state          TEXT        DEFAULT 'newCard',
  last_review    TIMESTAMPTZ,
  next_review    TIMESTAMPTZ,
  times_shown    INT         DEFAULT 0,
  times_correct  INT         DEFAULT 0,
  mastery_level  REAL        DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, variant_id, direction)
);
ALTER TABLE public.variant_progress ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_progress_user_next  ON public.variant_progress (user_id, next_review);
CREATE INDEX IF NOT EXISTS idx_progress_user_state ON public.variant_progress (user_id, state);
DROP POLICY IF EXISTS "progress_own" ON public.variant_progress;
CREATE POLICY "progress_own" ON public.variant_progress USING (user_id = auth.uid());

-- ─── FRIEND REQUESTS ──────────────────────────────────────────────────────────
-- Note: columns use _id suffix to match app code.
CREATE TABLE IF NOT EXISTS public.friend_requests (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  to_user_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status       TEXT        NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending','accepted','declined')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (from_user_id, to_user_id)
);
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View own requests"           ON public.friend_requests;
DROP POLICY IF EXISTS "Send friend request"         ON public.friend_requests;
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

-- ─── FRIENDSHIPS ──────────────────────────────────────────────────────────────
-- user_a_id < user_b_id (lexicographic) enforced by app to prevent duplicates.
CREATE TABLE IF NOT EXISTS public.friendships (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id  UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_b_id  UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_a_id, user_b_id)
);
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_friendships_a ON public.friendships (user_a_id);
CREATE INDEX IF NOT EXISTS idx_friendships_b ON public.friendships (user_b_id);
DROP POLICY IF EXISTS "View own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Create friendship"    ON public.friendships;
DROP POLICY IF EXISTS "Remove friendship"    ON public.friendships;
CREATE POLICY "View own friendships"
  ON public.friendships FOR SELECT
  USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);
CREATE POLICY "Create friendship"
  ON public.friendships FOR INSERT
  WITH CHECK (auth.uid() = user_a_id OR auth.uid() = user_b_id);
CREATE POLICY "Remove friendship"
  ON public.friendships FOR DELETE
  USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);

-- ─── VOCABULARY LISTS policies (after friendships exists) ─────────────────────
DROP POLICY IF EXISTS "lists_owner"   ON public.vocabulary_lists;
DROP POLICY IF EXISTS "lists_public"  ON public.vocabulary_lists;
DROP POLICY IF EXISTS "lists_friends" ON public.vocabulary_lists;
CREATE POLICY "lists_owner"  ON public.vocabulary_lists USING (owner_id = auth.uid());
CREATE POLICY "lists_public" ON public.vocabulary_lists FOR SELECT USING (visibility = 'public');
CREATE POLICY "lists_friends" ON public.vocabulary_lists FOR SELECT USING (
  visibility = 'friends' AND EXISTS (
    SELECT 1 FROM public.friendships
    WHERE (user_a_id = auth.uid() AND user_b_id = owner_id)
       OR (user_b_id = auth.uid() AND user_a_id = owner_id)
  )
);

-- ─── CONCEPTS policy (after vocabulary_lists) ─────────────────────────────────
DROP POLICY IF EXISTS "concepts_via_list" ON public.concepts;
CREATE POLICY "concepts_via_list" ON public.concepts USING (
  EXISTS (SELECT 1 FROM public.vocabulary_lists l WHERE l.id = list_id AND l.owner_id = auth.uid())
);

-- ─── WORD VARIANTS policy (after concepts) ────────────────────────────────────
DROP POLICY IF EXISTS "variants_via_concept" ON public.word_variants;
CREATE POLICY "variants_via_concept" ON public.word_variants USING (
  EXISTS (
    SELECT 1 FROM public.concepts c
    JOIN public.vocabulary_lists l ON l.id = c.list_id
    WHERE c.id = concept_id AND l.owner_id = auth.uid()
  )
);

-- ─── CHALLENGES ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.challenges (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id          UUID        REFERENCES public.vocabulary_lists(id),
  challenger_id    UUID        REFERENCES auth.users(id),
  challenged_id    UUID        REFERENCES auth.users(id),
  status           TEXT        DEFAULT 'pending',
  challenger_score INT,
  challenged_score INT,
  word_count       INT         DEFAULT 0,
  expires_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "challenges_own" ON public.challenges;
CREATE POLICY "challenges_own" ON public.challenges
  USING (challenger_id = auth.uid() OR challenged_id = auth.uid());

-- ─── LEADERBOARD ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.leaderboard_entries (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  period        TEXT NOT NULL,
  score         INT  DEFAULT 0,
  words_mastered INT DEFAULT 0,
  rank          INT,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, period)
);
ALTER TABLE public.leaderboard_entries ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_leaderboard_period ON public.leaderboard_entries (period, score DESC);
DROP POLICY IF EXISTS "leaderboard_select_all" ON public.leaderboard_entries;
DROP POLICY IF EXISTS "leaderboard_own"        ON public.leaderboard_entries;
CREATE POLICY "leaderboard_select_all" ON public.leaderboard_entries FOR SELECT USING (TRUE);
CREATE POLICY "leaderboard_own"        ON public.leaderboard_entries FOR ALL   USING (user_id = auth.uid());

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        REFERENCES auth.users(id) ON DELETE CASCADE,
  type       TEXT        NOT NULL,
  payload    JSONB       DEFAULT '{}',
  is_read    BOOL        DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications (user_id, is_read, created_at DESC);
DROP POLICY IF EXISTS "notifications_own" ON public.notifications;
CREATE POLICY "notifications_own" ON public.notifications USING (user_id = auth.uid());

-- ─── PROFILE AUTO-CREATION TRIGGER ───────────────────────────────────────────
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
