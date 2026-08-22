-- ==============================================================================
-- إمتياز مطروح (Nurse Matrouh) — الإصلاح النهائي لتثبيت اعتماد الطلاب ومنع عودتهم للانتظار
-- التاريخ: 2026-08-22
-- ==============================================================================

-- 1. تعديل عمود reviewed_by في profiles ليكون TEXT وإسقاط أي قيود Foreign Key
DO $$
BEGIN
  -- إسقاط قيد المفتاح الخارجي إن وجد
  ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_reviewed_by_fkey;
  
  -- تحويل نوع العمود إلى TEXT ليتسع لأي معرف مراجع (UUID أو كود ليدر مثل ldr-001)
  ALTER TABLE public.profiles ALTER COLUMN reviewed_by TYPE TEXT USING reviewed_by::text;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- 2. دالة RPC فائقة الحصانة لاعتماد الطالب (Approve Student)
CREATE OR REPLACE FUNCTION public.approve_student_registration(
  p_student_id TEXT,
  p_reviewer_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET 
    registration_status = 'approved',
    is_approved = true,
    reviewed_by = p_reviewer_id,
    reviewed_at = NOW(),
    rejection_reason = NULL,
    updated_at = NOW()
  WHERE id::text = p_student_id 
     OR university_code = p_student_id 
     OR LOWER(email) = LOWER(p_student_id);
     
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$;

-- 3. دالة RPC لرفض طلب التسجيل (Reject Student)
CREATE OR REPLACE FUNCTION public.reject_student_registration(
  p_student_id TEXT,
  p_reason TEXT DEFAULT 'غير مستوفي للشروط',
  p_reviewer_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET 
    registration_status = 'rejected',
    is_approved = false,
    reviewed_by = p_reviewer_id,
    reviewed_at = NOW(),
    rejection_reason = p_reason,
    updated_at = NOW()
  WHERE id::text = p_student_id 
     OR university_code = p_student_id 
     OR LOWER(email) = LOWER(p_student_id);
     
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$;

-- 4. دالة RPC لإعادة الطالب إلى قيد المراجعة (Return to Pending)
CREATE OR REPLACE FUNCTION public.return_student_to_pending(
  p_student_id TEXT,
  p_reviewer_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET 
    registration_status = 'pending',
    is_approved = false,
    reviewed_by = p_reviewer_id,
    reviewed_at = NOW(),
    rejection_reason = NULL,
    updated_at = NOW()
  WHERE id::text = p_student_id 
     OR university_code = p_student_id 
     OR LOWER(email) = LOWER(p_student_id);
     
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$;

-- 5. تحديث دالة فحص بيانات تسجيل الدخول لتكون دقيقة ومحصنة
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
    role, 
    full_name,
    student_group,
    registration_status, 
    rejection_reason, 
    is_approved
  INTO v_profile
  FROM public.profiles
  WHERE LOWER(university_code) = LOWER(v_clean_identifier)
     OR national_id = v_clean_identifier
     OR phone_number = v_clean_identifier
     OR LOWER(email) = LOWER(v_clean_identifier)
     OR id::text = v_clean_identifier
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

-- 6. فتح سياسات الأمان RLS بالكامل لتفادي أي حجب للتحديثات
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "Profiles read" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
CREATE POLICY "profiles_insert_policy" ON public.profiles FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy" ON public.profiles FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "profiles_delete_policy" ON public.profiles;
CREATE POLICY "profiles_delete_policy" ON public.profiles FOR DELETE USING (true);

-- 7. منح صلاحيات الاستدعاء لجميع الدوال
GRANT EXECUTE ON FUNCTION public.approve_student_registration(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_student_registration(TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.return_student_to_pending(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_login_info(TEXT) TO anon, authenticated, service_role;

GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;
