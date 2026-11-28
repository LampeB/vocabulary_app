-- Disposable database at migration 021. Real pre-upgrade profile summaries.
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
  ('22000000-0000-4000-8000-000000000001','study-latest-first@example.invalid','{"username":"study_latest_first"}'),
  ('22000000-0000-4000-8000-000000000002','study-oldest-first@example.invalid','{"username":"study_oldest_first"}'),
  ('22000000-0000-4000-8000-000000000003','study-legacy-bound@example.invalid','{"username":"study_legacy_bound"}');
UPDATE public.profiles SET current_streak=5,longest_streak=5,last_study_date='2026-11-24'
  WHERE id='22000000-0000-4000-8000-000000000001';
UPDATE public.profiles SET current_streak=5,longest_streak=10,last_study_date='2026-11-24'
  WHERE id='22000000-0000-4000-8000-000000000002';
UPDATE public.profiles SET current_streak=2147483647,longest_streak=2147483647,last_study_date='2026-11-24'
  WHERE id='22000000-0000-4000-8000-000000000003';
