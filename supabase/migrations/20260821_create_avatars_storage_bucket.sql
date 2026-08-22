-- ==============================================================================
-- Migration: Create Avatars Storage Bucket & Public Access Policies
-- Date: 2026-08-21
-- Purpose: Enable direct gallery/camera image upload for profile avatars & leaderboard
-- ==============================================================================

-- 1. Create 'avatars' storage bucket as PUBLIC
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880, -- 5 MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml'];

-- 2. Drop existing avatar policies if any to avoid conflict
DROP POLICY IF EXISTS "Public Read Avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow All Upload Avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow All Update Avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow All Delete Avatars" ON storage.objects;

-- 3. Public Read Policy (Anyone can view avatars so leaderboard works for all)
CREATE POLICY "Public Read Avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- 4. Upload Policy (Authenticated & Registered students can upload their avatars)
CREATE POLICY "Allow All Upload Avatars"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars');

-- 5. Update / Upsert Policy
CREATE POLICY "Allow All Update Avatars"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars');

-- 6. Delete Policy
CREATE POLICY "Allow All Delete Avatars"
ON storage.objects FOR DELETE
USING (bucket_id = 'avatars');
