-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- USER PROFILES
CREATE TABLE public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username      TEXT UNIQUE NOT NULL CHECK (length(username) >= 3),
  display_name  TEXT,
  avatar_url    TEXT,
  bio           TEXT,
  total_words_mastered INT DEFAULT 0,
  current_streak       INT DEFAULT 0,
  longest_streak       INT DEFAULT 0,
  last_study_date      DATE,
  is_premium    BOOL DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_select_public" ON public.profiles FOR SELECT USING (TRUE);

-- SUBSCRIPTIONS
CREATE TABLE public.subscriptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  rc_customer_id  TEXT UNIQUE,
  tier            TEXT DEFAULT 'free' CHECK (tier IN ('free','premium','premium_annual')),
  status          TEXT DEFAULT 'active' CHECK (status IN ('active','expired','cancelled')),
  expires_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "subscriptions_own" ON public.subscriptions USING (user_id = auth.uid());

-- VOCABULARY LISTS
CREATE TABLE public.vocabulary_lists (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  description   TEXT,
  visibility    TEXT DEFAULT 'private' CHECK (visibility IN ('private','friends','public')),
  word_count    INT DEFAULT 0,
  share_token   TEXT UNIQUE,
  is_deleted    BOOL DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.vocabulary_lists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "lists_owner" ON public.vocabulary_lists USING (owner_id = auth.uid());
CREATE POLICY "lists_public" ON public.vocabulary_lists FOR SELECT USING (visibility = 'public');
CREATE POLICY "lists_friends" ON public.vocabulary_lists FOR SELECT USING (
  visibility = 'friends' AND EXISTS (
    SELECT 1 FROM public.friendships
    WHERE (user_a = auth.uid() AND user_b = owner_id)
       OR (user_b = auth.uid() AND user_a = owner_id)
  )
);
CREATE INDEX ON public.vocabulary_lists (owner_id);
CREATE INDEX ON public.vocabulary_lists (share_token);

-- CONCEPTS
CREATE TABLE public.concepts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id     UUID REFERENCES public.vocabulary_lists(id) ON DELETE CASCADE,
  category    TEXT,
  notes       TEXT,
  image_url   TEXT,
  example_fr  TEXT,
  example_ko  TEXT,
  is_deleted  BOOL DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.concepts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "concepts_via_list" ON public.concepts USING (
  EXISTS (SELECT 1 FROM public.vocabulary_lists l WHERE l.id = list_id AND l.owner_id = auth.uid())
);
CREATE INDEX ON public.concepts (list_id);

-- WORD VARIANTS
CREATE TABLE public.word_variants (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_id    UUID REFERENCES public.concepts(id) ON DELETE CASCADE,
  word          TEXT NOT NULL,
  lang_code     TEXT NOT NULL CHECK (lang_code IN ('fr','ko')),
  register_tag  TEXT DEFAULT 'neutral',
  context_tags  JSONB DEFAULT '[]',
  is_primary    BOOL DEFAULT FALSE,
  audio_hash    TEXT,
  audio_voice_id TEXT,
  position      INT DEFAULT 0,
  is_deleted    BOOL DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.word_variants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "variants_via_concept" ON public.word_variants USING (
  EXISTS (
    SELECT 1 FROM public.concepts c
    JOIN public.vocabulary_lists l ON l.id = c.list_id
    WHERE c.id = concept_id AND l.owner_id = auth.uid()
  )
);
CREATE INDEX ON public.word_variants (concept_id, lang_code);
CREATE INDEX ON public.word_variants (audio_hash);

-- VARIANT PROGRESS
CREATE TABLE public.variant_progress (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  variant_id      UUID REFERENCES public.word_variants(id) ON DELETE CASCADE,
  direction       TEXT NOT NULL CHECK (direction IN ('frToKo','koToFr')),
  stability       REAL DEFAULT 0,
  difficulty      REAL DEFAULT 5,
  elapsed_days    INT DEFAULT 0,
  scheduled_days  INT DEFAULT 0,
  reps            INT DEFAULT 0,
  lapses          INT DEFAULT 0,
  state           TEXT DEFAULT 'newCard',
  last_review     TIMESTAMPTZ,
  next_review     TIMESTAMPTZ,
  times_shown     INT DEFAULT 0,
  times_correct   INT DEFAULT 0,
  mastery_level   REAL DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, variant_id, direction)
);
ALTER TABLE public.variant_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "progress_own" ON public.variant_progress USING (user_id = auth.uid());
CREATE INDEX ON public.variant_progress (user_id, next_review);
CREATE INDEX ON public.variant_progress (user_id, state);

-- FRIEND REQUESTS
CREATE TABLE public.friend_requests (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user   UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  to_user     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status      TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (from_user, to_user)
);
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "friend_requests_own" ON public.friend_requests
  USING (from_user = auth.uid() OR to_user = auth.uid());

-- FRIENDSHIPS
CREATE TABLE public.friendships (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  user_b      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "friendships_own" ON public.friendships
  USING (user_a = auth.uid() OR user_b = auth.uid());
CREATE INDEX ON public.friendships (user_a);
CREATE INDEX ON public.friendships (user_b);

-- CHALLENGES
CREATE TABLE public.challenges (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id         UUID REFERENCES public.vocabulary_lists(id),
  challenger_id   UUID REFERENCES auth.users(id),
  challenged_id   UUID REFERENCES auth.users(id),
  status          TEXT DEFAULT 'pending',
  challenger_score INT,
  challenged_score INT,
  word_count      INT DEFAULT 0,
  expires_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "challenges_own" ON public.challenges
  USING (challenger_id = auth.uid() OR challenged_id = auth.uid());

-- LEADERBOARD
CREATE TABLE public.leaderboard_entries (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  period        TEXT NOT NULL,
  score         INT DEFAULT 0,
  words_mastered INT DEFAULT 0,
  rank          INT,
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, period)
);
ALTER TABLE public.leaderboard_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "leaderboard_select_all" ON public.leaderboard_entries FOR SELECT USING (TRUE);
CREATE POLICY "leaderboard_own" ON public.leaderboard_entries
  FOR ALL USING (user_id = auth.uid());
CREATE INDEX ON public.leaderboard_entries (period, score DESC);

-- NOTIFICATIONS
CREATE TABLE public.notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,
  payload     JSONB DEFAULT '{}',
  is_read     BOOL DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notifications_own" ON public.notifications USING (user_id = auth.uid());
CREATE INDEX ON public.notifications (user_id, is_read, created_at DESC);
