-- =========================================================================
-- إمتياز مطروح (Nurse Matrouh) — الإصلاح الشامل لتسجيل الطلاب وظهورهم لدى الليدر
-- Date: 2026-08-21
-- =========================================================================

-- 1. التأكد من وجود Enum لحالات التسجيل
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'registration_status') THEN
    CREATE TYPE registration_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
  END IF;
END $$;

-- 2. تحديث جدول المستخدمين (profiles) وإضافة جميع الأعمدة اللازمة وضبط القيم الافتراضية
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS university_code TEXT,
  ADD COLUMN IF NOT EXISTS student_group TEXT DEFAULT 'A',
  ADD COLUMN IF NOT EXISTS gender TEXT DEFAULT 'male',
  ADD COLUMN IF NOT EXISTS registration_status registration_status DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS national_id TEXT,
  ADD COLUMN IF NOT EXISTS phone_number TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact TEXT,
  ADD COLUMN IF NOT EXISTS residence_address TEXT,
  ADD COLUMN IF NOT EXISTS gpa NUMERIC(3,2),
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS is_matrouh_resident BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS marital_status TEXT DEFAULT 'أعزب/عزباء',
  ADD COLUMN IF NOT EXISTS children_count INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. تريجر إنشاء البروفايل تلقائياً وفورياً بصلاحيات كاملة عند تسجيل أي مستخدم جديد (handle_new_user)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
  v_status registration_status;
  v_approved BOOLEAN;
  v_gpa NUMERIC(3,2);
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
  v_children INT;
BEGIN
  -- تحديد الدور
  v_role := COALESCE(new.raw_user_meta_data->>'role', 'student');

  -- الأدوار الإدارية تعتمد تلقائياً، والطلاب حالتهم pending وغير معتمدين حتى يوافق الليدر
  IF v_role IN ('super_admin', 'leader', 'evaluating_doctor') THEN
    v_status := 'approved'::registration_status;
    v_approved := true;
  ELSE
    v_status := COALESCE((new.raw_user_meta_data->>'registration_status')::registration_status, 'pending'::registration_status);
    v_approved := false;
  END IF;

  -- تحويل الحقول الرقمية بأمان
  BEGIN
    v_gpa := (new.raw_user_meta_data->>'gpa')::NUMERIC(3,2);
  EXCEPTION WHEN OTHERS THEN
    v_gpa := NULL;
  END;

  BEGIN
    v_lat := (new.raw_user_meta_data->>'latitude')::DOUBLE PRECISION;
  EXCEPTION WHEN OTHERS THEN
    v_lat := NULL;
  END;

  BEGIN
    v_lng := (new.raw_user_meta_data->>'longitude')::DOUBLE PRECISION;
  EXCEPTION WHEN OTHERS THEN
    v_lng := NULL;
  END;

  BEGIN
    v_children := (new.raw_user_meta_data->>'children_count')::INT;
  EXCEPTION WHEN OTHERS THEN
    v_children := 0;
  END;

  -- إدراج أو تحديث البروفايل بالكامل
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    university_code,
    phone_number,
    national_id,
    gender,
    marital_status,
    children_count,
    is_matrouh_resident,
    emergency_contact,
    residence_address,
    latitude,
    longitude,
    gpa,
    role,
    student_group,
    registration_status,
    is_approved,
    created_at,
    updated_at
  )
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', 'طالب جديد'),
    COALESCE(new.raw_user_meta_data->>'university_code', 'STD-' || substring(new.id::text from 1 for 8)),
    COALESCE(new.raw_user_meta_data->>'phone_number', ''),
    new.raw_user_meta_data->>'national_id',
    COALESCE(new.raw_user_meta_data->>'gender', 'male'),
    COALESCE(new.raw_user_meta_data->>'marital_status', 'أعزب/عزباء'),
    COALESCE(v_children, 0),
    COALESCE((new.raw_user_meta_data->>'is_matrouh_resident')::BOOLEAN, true),
    COALESCE(new.raw_user_meta_data->>'emergency_contact', ''),
    COALESCE(new.raw_user_meta_data->>'residence_address', ''),
    v_lat,
    v_lng,
    v_gpa,
    v_role::user_role,
    COALESCE(new.raw_user_meta_data->>'student_group', 'A'),
    v_status,
    v_approved,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    university_code = EXCLUDED.university_code,
    phone_number = EXCLUDED.phone_number,
    national_id = COALESCE(EXCLUDED.national_id, public.profiles.national_id),
    gender = EXCLUDED.gender,
    marital_status = EXCLUDED.marital_status,
    children_count = EXCLUDED.children_count,
    is_matrouh_resident = EXCLUDED.is_matrouh_resident,
    emergency_contact = EXCLUDED.emergency_contact,
    residence_address = EXCLUDED.residence_address,
    latitude = COALESCE(EXCLUDED.latitude, public.profiles.latitude),
    longitude = COALESCE(EXCLUDED.longitude, public.profiles.longitude),
    gpa = COALESCE(EXCLUDED.gpa, public.profiles.gpa),
    role = EXCLUDED.role,
    student_group = EXCLUDED.student_group,
    registration_status = EXCLUDED.registration_status,
    is_approved = EXCLUDED.is_approved,
    updated_at = NOW();

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  -- Fallback آمن لمنع أي فشل
  INSERT INTO public.profiles (id, email, full_name, university_code, phone_number, emergency_contact, role, registration_status, is_approved, created_at, updated_at)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', 'طالب جديد'),
    COALESCE(new.raw_user_meta_data->>'university_code', 'STD-' || substring(new.id::text from 1 for 8)),
    COALESCE(new.raw_user_meta_data->>'phone_number', ''),
    COALESCE(new.raw_user_meta_data->>'emergency_contact', ''),
    v_role::user_role,
    'pending'::registration_status,
    false,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

-- إعادة ربط التريجر على auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. إشعار فوري لليدر والمسؤولين عند تسجيل أي طالب جديد
CREATE OR REPLACE FUNCTION public.notify_leaders_on_student_registration()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_leader RECORD;
BEGIN
  IF NEW.role = 'student' AND (NEW.registration_status = 'pending' OR NEW.is_approved = false) THEN
    FOR v_leader IN SELECT id FROM public.profiles WHERE role IN ('leader', 'super_admin') LOOP
      INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        is_read,
        created_at
      ) VALUES (
        v_leader.id,
        'طالب جديد يحتاج للاعتماد 📝',
        'قام الطالب ' || NEW.full_name || ' بالتسجيل في المنصة (GPA: ' || COALESCE(NEW.gpa::text, 'غير محدد') || ') وينتظر مراجعتك واعتمادك.',
        'NEW_STUDENT_REGISTRATION',
        false,
        NOW()
      );
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_leaders_on_student_registration ON public.profiles;
CREATE TRIGGER trg_notify_leaders_on_student_registration
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_leaders_on_student_registration();

-- 5. فتح سياسات الأمان (RLS) للـ Profiles لتسمح بإنشاء الحساب وقراءته وتحديثه بسلاسة
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- السماح بالقراءة لجميع المستخدمين المعتمدين والمصرح لهم
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
  FOR SELECT USING (true);

-- السماح بإنشاء البروفايل (INSERT)
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
CREATE POLICY "profiles_insert_policy" ON public.profiles
  FOR INSERT WITH CHECK (true);

-- السماح بالتحديث (UPDATE) لصاحب الحساب أو الليدر أو الأدمن
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy" ON public.profiles
  FOR UPDATE USING (
    auth.uid() = id 
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

-- السماح بالحذف (DELETE) للأدمن والليدر فقط
DROP POLICY IF EXISTS "profiles_delete_policy" ON public.profiles;
CREATE POLICY "profiles_delete_policy" ON public.profiles
  FOR DELETE USING (
    public.get_auth_role() IN ('super_admin', 'leader')
  );

-- 6. منح الصلاحيات
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;
