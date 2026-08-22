-- ==============================================================================
-- MIGRATION: Fix App Versions RLS Policies & Storage Access
-- Date: 2026-08-22
-- File: 20260822_fix_app_versions_rls.sql
-- ==============================================================================

-- 1. التأكد من وجود الجدول وحقوله بالكامل
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

ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS platform TEXT NOT NULL DEFAULT 'android';
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS file_name TEXT;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS file_size BIGINT;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS checksum TEXT;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS force_update BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS minimum_supported_version INT NOT NULL DEFAULT 1;
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_app_versions_code ON public.app_versions(version_code DESC);
CREATE INDEX IF NOT EXISTS idx_app_versions_active ON public.app_versions(platform, is_active) WHERE is_active = true;

-- 2. إعطاء الصلاحيات وتفعيل أمان الصفوف RLS
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.app_versions TO postgres, anon, authenticated, service_role;

-- حذف السياسات القديمة منعاً للتعارض
DROP POLICY IF EXISTS "app_versions_select_policy" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_select_all_active" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_admin_manage" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_insert_admin_only" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_update_admin_only" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_delete_admin_only" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_select_policy_v2" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_insert_policy_v2" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_update_policy_v2" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_delete_policy_v2" ON public.app_versions;

-- القراءة: متاح للجميع قراءة الإصدارات النشطة، وللإدارة ولليدر قراءة كل الإصدارات
CREATE POLICY "app_versions_select_policy_v2" ON public.app_versions
  FOR SELECT USING (
    is_active = true 
    OR public.get_auth_role()::text IN ('super_admin', 'leader')
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role::text IN ('super_admin', 'leader')
    )
  );

-- الإضافة: مصرح لـ super_admin و leader
CREATE POLICY "app_versions_insert_policy_v2" ON public.app_versions
  FOR INSERT WITH CHECK (
    public.get_auth_role()::text IN ('super_admin', 'leader')
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role::text IN ('super_admin', 'leader')
    )
  );

-- التعديل: مصرح لـ super_admin و leader
CREATE POLICY "app_versions_update_policy_v2" ON public.app_versions
  FOR UPDATE USING (
    public.get_auth_role()::text IN ('super_admin', 'leader')
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role::text IN ('super_admin', 'leader')
    )
  )
  WITH CHECK (
    public.get_auth_role()::text IN ('super_admin', 'leader')
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role::text IN ('super_admin', 'leader')
    )
  );

-- الحذف: مصرح لـ super_admin و leader
CREATE POLICY "app_versions_delete_policy_v2" ON public.app_versions
  FOR DELETE USING (
    public.get_auth_role()::text IN ('super_admin', 'leader')
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role::text IN ('super_admin', 'leader')
    )
  );

-- 3. إعداد حاوية التخزين app-releases وسياساتها
INSERT INTO storage.buckets (id, name, public) VALUES
  ('app-releases', 'app-releases', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "app_releases_public_read" ON storage.objects;
DROP POLICY IF EXISTS "app_releases_public_read_v2" ON storage.objects;
CREATE POLICY "app_releases_public_read_v2" ON storage.objects
  FOR SELECT USING (bucket_id = 'app-releases');

DROP POLICY IF EXISTS "app_releases_admin_upload" ON storage.objects;
DROP POLICY IF EXISTS "app_releases_admin_upload_v2" ON storage.objects;
CREATE POLICY "app_releases_admin_upload_v2" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'app-releases'
    AND (
      public.get_auth_role()::text IN ('super_admin', 'leader')
      OR EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role::text IN ('super_admin', 'leader')
      )
    )
  );

DROP POLICY IF EXISTS "app_releases_admin_update" ON storage.objects;
DROP POLICY IF EXISTS "app_releases_admin_update_v2" ON storage.objects;
CREATE POLICY "app_releases_admin_update_v2" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'app-releases'
    AND (
      public.get_auth_role()::text IN ('super_admin', 'leader')
      OR EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role::text IN ('super_admin', 'leader')
      )
    )
  );

DROP POLICY IF EXISTS "app_releases_admin_delete" ON storage.objects;
DROP POLICY IF EXISTS "app_releases_admin_delete_v2" ON storage.objects;
CREATE POLICY "app_releases_admin_delete_v2" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'app-releases'
    AND (
      public.get_auth_role()::text IN ('super_admin', 'leader')
      OR EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role::text IN ('super_admin', 'leader')
      )
    )
  );
