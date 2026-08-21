-- ========================================================
-- PROJECT: إمتياز مطروح (Nurse Matrouh)
-- Migration: Secure Login Lookup by Code/National ID & RLS Fix
-- Date: 2026-08-16
-- ========================================================

-- 1. Function to safely resolve user email, role, and approval status before login
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

-- Grant execution to anon and authenticated
GRANT EXECUTE ON FUNCTION public.get_user_login_info(TEXT) TO anon, authenticated;

-- 2. Allow Leader and Super Admin to read and approve pending students
DROP POLICY IF EXISTS "Profiles read" ON public.profiles;
CREATE POLICY "Profiles read" ON public.profiles
  FOR SELECT USING (
    auth.uid() = id 
    OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
  );

DROP POLICY IF EXISTS "Profiles leader update" ON public.profiles;
CREATE POLICY "Profiles leader update" ON public.profiles
  FOR UPDATE USING (
    auth.uid() = id 
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );
