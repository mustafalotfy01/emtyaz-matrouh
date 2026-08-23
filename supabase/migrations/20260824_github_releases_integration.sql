-- ============================================================================
-- Migration: 20260824_github_releases_integration.sql
-- Description: Extends public.app_versions table to support GitHub Releases
-- metadata, SHA256 integrity checksums, and strict Super Admin RLS enforcement.
-- ============================================================================

-- 1. Extend public.app_versions schema with GitHub Releases metadata
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS github_release_id BIGINT;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS github_tag_name TEXT;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS github_asset_id BIGINT;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS release_url TEXT;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS sha256 TEXT;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ DEFAULT now();

-- 2. Ensure apk_download_url / download_url consistency
-- If download_url column does not exist, ensure backward compatibility
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'app_versions' AND column_name = 'download_url'
  ) THEN
    ALTER TABLE public.app_versions ADD COLUMN download_url TEXT;
    UPDATE public.app_versions SET download_url = apk_download_url WHERE download_url IS NULL;
  END IF;
END $$;

-- 3. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_app_versions_tag ON public.app_versions(github_tag_name);
CREATE INDEX IF NOT EXISTS idx_app_versions_platform_code ON public.app_versions(platform, version_code DESC);

-- 4. Re-enforce Row Level Security (RLS)
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Drop legacy policies safely
DROP POLICY IF EXISTS "app_versions_select_all_active" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_select_policy" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_admin_manage" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_insert_admin_only" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_update_admin_only" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_delete_admin_only" ON public.app_versions;

-- A) SELECT Policy: Anyone (students, doctors, leaders, anon) can read active releases; Super Admins can read all
CREATE POLICY "app_versions_select_policy" ON public.app_versions
  FOR SELECT
  USING (
    is_active = true
    OR (
      auth.uid() IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND role = 'super_admin'
      )
    )
  );

-- B) INSERT Policy: Strictly Super Admin
CREATE POLICY "app_versions_insert_super_admin_only" ON public.app_versions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- C) UPDATE Policy: Strictly Super Admin
CREATE POLICY "app_versions_update_super_admin_only" ON public.app_versions
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- D) DELETE Policy: Strictly Super Admin
CREATE POLICY "app_versions_delete_super_admin_only" ON public.app_versions
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- 5. Grant permissions to standard Supabase roles
GRANT ALL ON public.app_versions TO postgres, service_role;
GRANT SELECT ON public.app_versions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.app_versions TO authenticated;
