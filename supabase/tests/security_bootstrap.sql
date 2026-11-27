-- Disposable PostgreSQL only. Minimal substitutes for Supabase-owned schemas;
-- production application tables and policies must come from real migrations.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
CREATE SCHEMA storage;
CREATE TABLE auth.users (
  id uuid PRIMARY KEY, email text,
  raw_user_meta_data jsonb DEFAULT '{}', raw_app_meta_data jsonb DEFAULT '{}'
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
GRANT USAGE ON SCHEMA auth, storage, public TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO authenticated, service_role;
CREATE TABLE storage.buckets(id text PRIMARY KEY, name text, public boolean,
  file_size_limit bigint, allowed_mime_types text[]);
CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text, name text);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON storage.objects TO anon, authenticated;
-- Model a pre-existing Storage policy that remains across the migrations.
CREATE POLICY fixture_existing_storage_read ON storage.objects
  FOR SELECT TO anon, authenticated USING (true);
