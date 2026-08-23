-- ==============================================================================
-- MIGRATION: Upgrade App Releases Storage Capacity & Secure RLS
-- Date: 2026-08-23
-- File: 20260823_upgrade_app_releases_storage_and_rls.sql
-- Description:
--   1. Updates 'app-releases' bucket in storage.buckets to support files up to 500MB
--      (file_size_limit = 524288000).
--   2. Ensures public READ access to APK files for all users.
--   3. Enforces super_admin ONLY permissions for INSERT, UPDATE, and DELETE.
--   4. Validates app_versions table schema and indexes.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. STORAGE BUCKET CONFIGURATION (500MB MAX SIZE)
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'app-releases',
  'app-releases',
  true,
  524288000, -- 500 MB in bytes
  ARRAY[
    'application/vnd.android.package-archive',
    'application/octet-stream',
    'application/x-zip-compressed'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 524288000,
  allowed_mime_types = ARRAY[
    'application/vnd.android.package-archive',
    'application/octet-stream',
    'application/x-zip-compressed'
  ];

-- ------------------------------------------------------------------------------
-- 2. STORAGE OBJECTS RLS POLICIES FOR app-releases BUCKET
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "app_releases_public_read" ON storage.objects;
CREATE POLICY "app_releases_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'app-releases');

DROP POLICY IF EXISTS "app_releases_admin_upload" ON storage.objects;
CREATE POLICY "app_releases_admin_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'app-releases'
    AND public.get_auth_role() = 'super_admin'
  );

DROP POLICY IF EXISTS "app_releases_admin_update" ON storage.objects;
CREATE POLICY "app_releases_admin_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'app-releases'
    AND public.get_auth_role() = 'super_admin'
  );

DROP POLICY IF EXISTS "app_releases_admin_delete" ON storage.objects;
CREATE POLICY "app_releases_admin_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'app-releases'
    AND public.get_auth_role() = 'super_admin'
  );

-- ------------------------------------------------------------------------------
-- 3. APP_VERSIONS TABLE SCHEMA & POLICIES VERIFICATION
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_name TEXT NOT NULL,
    version_code INT UNIQUE NOT NULL,
    apk_download_url TEXT NOT NULL,
    release_notes TEXT,
    force_update BOOLEAN NOT NULL DEFAULT false,
    minimum_supported_version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    platform TEXT NOT NULL DEFAULT 'android',
    file_name TEXT,
    file_size BIGINT,
    checksum TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    release_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.app_versions TO postgres, anon, authenticated, service_role;

DROP POLICY IF EXISTS "app_versions_select_all_active" ON public.app_versions;
CREATE POLICY "app_versions_select_all_active" ON public.app_versions
  FOR SELECT USING (is_active = true OR public.get_auth_role() = 'super_admin');

DROP POLICY IF EXISTS "app_versions_insert_admin_only" ON public.app_versions;
CREATE POLICY "app_versions_insert_admin_only" ON public.app_versions
  FOR INSERT WITH CHECK (public.get_auth_role() = 'super_admin');

DROP POLICY IF EXISTS "app_versions_update_admin_only" ON public.app_versions;
CREATE POLICY "app_versions_update_admin_only" ON public.app_versions
  FOR UPDATE USING (public.get_auth_role() = 'super_admin')
  WITH CHECK (public.get_auth_role() = 'super_admin');

DROP POLICY IF EXISTS "app_versions_delete_admin_only" ON public.app_versions;
CREATE POLICY "app_versions_delete_admin_only" ON public.app_versions
  FOR DELETE USING (public.get_auth_role() = 'super_admin');
