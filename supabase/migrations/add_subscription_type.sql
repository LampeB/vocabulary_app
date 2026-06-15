-- Add subscription_type column to profiles.
-- Values: 'free' (default), 'student' (teacher-granted), 'premium' (manual admin grant).
-- To grant student access: UPDATE profiles SET subscription_type = 'student' WHERE id = '<user-id>';
-- To revoke:               UPDATE profiles SET subscription_type = 'free'    WHERE id = '<user-id>';

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS subscription_type TEXT NOT NULL DEFAULT 'free'
    CHECK (subscription_type IN ('free', 'student', 'premium'));

-- Migrate any existing manually-set premium users.
UPDATE profiles SET subscription_type = 'premium' WHERE is_premium = true;
