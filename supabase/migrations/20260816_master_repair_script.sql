-- =========================================================================
-- إمتياز مطروح (Nurse Matrouh) — MASTER DATABASE REPAIR & SETUP SCRIPT (V3)
-- =========================================================================

-- 1. التأكد من وجود Enum لحالات التسجيل
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'registration_status') THEN
    CREATE TYPE registration_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
  END IF;
END $$;

-- 2. تحديث جدول المستخدمين (profiles) بجميع الحقول المطلوبة
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS university_code TEXT,
  ADD COLUMN IF NOT EXISTS student_group TEXT DEFAULT 'A',
  ADD COLUMN IF NOT EXISTS gender TEXT DEFAULT 'male',
  ADD COLUMN IF NOT EXISTS registration_status registration_status DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS national_id TEXT,
  ADD COLUMN IF NOT EXISTS phone_number TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- 3. تفعيل واعتماد جميع الحسابات الموجودة حالياً فوراً
UPDATE public.profiles 
SET 
  registration_status = 'approved',
  is_approved = true,
  reviewed_at = NOW()
WHERE registration_status IS NULL OR registration_status = 'pending' OR is_approved IS FALSE;

-- 4. إعادة بناء جدول تفضيلات الروستر (roster_preferences)
DROP TABLE IF EXISTS public.roster_preferences CASCADE;

CREATE TABLE public.roster_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  roster_id TEXT NOT NULL,
  preference_date DATE NOT NULL,
  preference_type TEXT NOT NULL CHECK (preference_type IN ('A', 'B')),
  status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted', 'locked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_student_roster_pref UNIQUE(student_id, roster_id, preference_date)
);

-- 5. إعادة بناء جدول الشيفتات المعتمدة (shifts)
DROP TABLE IF EXISTS public.shifts CASCADE;

CREATE TABLE public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roster_id TEXT NOT NULL,
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  department_id TEXT NOT NULL DEFAULT 'dept-1',
  shift_date DATE NOT NULL,
  shift_type TEXT NOT NULL CHECK (shift_type IN ('morning', 'evening', 'night', 'long', 'off')),
  status TEXT NOT NULL DEFAULT 'approved' CHECK (status IN ('draft', 'approved', 'completed', 'cancelled')),
  preference_type TEXT,
  approved_by UUID REFERENCES public.profiles(id),
  approved_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_student_shift_date UNIQUE(roster_id, student_id, shift_date)
);

-- 6. إنشاء جدول شهور الروستر (roster_months)
CREATE TABLE IF NOT EXISTS public.roster_months (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  year INT NOT NULL,
  month INT NOT NULL,
  is_open_for_preferences BOOLEAN DEFAULT true,
  is_published BOOLEAN DEFAULT false,
  published_at TIMESTAMPTZ,
  published_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- إضافة الشهر الافتراضي (أغسطس 2026)
INSERT INTO public.roster_months (id, title, year, month, is_open_for_preferences, is_published)
VALUES ('roster-2026-08', 'روستر شهر أغسطس 2026', 2026, 8, true, false)
ON CONFLICT (id) DO NOTHING;

-- 7. دالة جلب دور المستخدم
DROP FUNCTION IF EXISTS public.get_auth_role() CASCADE;

CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT role::text FROM public.profiles WHERE id = auth.uid()),
    'student'
  );
$$;

-- 8. دالة تسجيل الدخول الذكية (بالكود الجامعي / الإيميل / الرقم القومي / الهاتف)
CREATE OR REPLACE FUNCTION public.get_user_login_info(p_identifier TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_profile RECORD;
  v_clean_identifier TEXT;
BEGIN
  v_clean_identifier := TRIM(p_identifier);

  SELECT 
    id,
    email, 
    role::text AS role, 
    full_name,
    student_group,
    registration_status::text AS registration_status, 
    rejection_reason, 
    is_approved
  INTO v_profile
  FROM public.profiles
  WHERE LOWER(university_code) = LOWER(v_clean_identifier)
     OR national_id = v_clean_identifier
     OR phone_number = v_clean_identifier
     OR LOWER(email) = LOWER(v_clean_identifier)
  LIMIT 1;

  IF v_profile IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'id', v_profile.id,
    'email', v_profile.email,
    'role', v_profile.role,
    'full_name', v_profile.full_name,
    'student_group', v_profile.student_group,
    'registration_status', v_profile.registration_status,
    'rejection_reason', v_profile.rejection_reason,
    'is_approved', v_profile.is_approved
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_login_info(TEXT) TO anon, authenticated;

-- 9. ضبط أمان الجداول والصلاحيات (Row Level Security - RLS)

-- تفعيل RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roster_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roster_months ENABLE ROW LEVEL SECURITY;

-- سياسات profiles
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy" ON public.profiles
  FOR UPDATE USING (
    auth.uid() = id 
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

-- سياسات roster_preferences
DROP POLICY IF EXISTS "roster_pref_select" ON public.roster_preferences;
CREATE POLICY "roster_pref_select" ON public.roster_preferences
  FOR SELECT USING (
    student_id = auth.uid() 
    OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
  );

DROP POLICY IF EXISTS "roster_pref_insert" ON public.roster_preferences;
CREATE POLICY "roster_pref_insert" ON public.roster_preferences
  FOR INSERT WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "roster_pref_update" ON public.roster_preferences;
CREATE POLICY "roster_pref_update" ON public.roster_preferences
  FOR UPDATE USING (
    student_id = auth.uid() 
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

-- سياسات shifts
DROP POLICY IF EXISTS "shifts_select_policy" ON public.shifts;
CREATE POLICY "shifts_select_policy" ON public.shifts
  FOR SELECT USING (
    student_id = auth.uid() 
    OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
  );

DROP POLICY IF EXISTS "shifts_leader_manage" ON public.shifts;
CREATE POLICY "shifts_leader_manage" ON public.shifts
  FOR ALL USING (public.get_auth_role() IN ('super_admin', 'leader'));

-- سياسات roster_months
DROP POLICY IF EXISTS "roster_months_select" ON public.roster_months;
CREATE POLICY "roster_months_select" ON public.roster_months
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "roster_months_manage" ON public.roster_months;
CREATE POLICY "roster_months_manage" ON public.roster_months
  FOR ALL USING (public.get_auth_role() IN ('super_admin', 'leader'));

-- 10. إعطاء الصلاحيات الكاملة
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;
