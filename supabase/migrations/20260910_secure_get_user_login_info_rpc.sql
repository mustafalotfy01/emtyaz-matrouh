-- ==============================================================================
-- MIGRATION: Secure get_user_login_info RPC & Prevent PII Scraping
-- Date: 2026-09-10
-- File: 20260910_secure_get_user_login_info_rpc.sql
-- Reason: Fix Critical Security Vulnerability (Item 5):
--   1. Revoke EXECUTE from 'anon' and 'public' to prevent unauthenticated scraping.
--   2. Enforce caller authentication via auth.uid() inside the RPC.
--   3. Enforce object-level authorization:
--      - 'super_admin' & 'service_role' can inspect profiles.
--      - 'leader' can inspect student profiles or their own account.
--      - 'student' and 'evaluating_doctor' can ONLY query their OWN account.
--   4. Prevent user enumeration: unauthorized target queries throw 42501.
--   5. Minimize returned fields: exclude national_id, phone_number, rejection_reason, GPS.
-- ==============================================================================

-- 1. Revoke public and anon execution privileges
REVOKE ALL ON FUNCTION public.get_user_login_info(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_login_info(TEXT) FROM anon;

-- 2. Grant execute only to authenticated users and service_role
GRANT EXECUTE ON FUNCTION public.get_user_login_info(TEXT) TO authenticated, service_role;

-- 3. Replace get_user_login_info with strict authentication, authorization, and data minimization
CREATE OR REPLACE FUNCTION public.get_user_login_info(p_identifier TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role TEXT;
  v_profile RECORD;
  v_clean_identifier TEXT;
BEGIN
  -- A. Enforce Caller Authentication: anon and unauthenticated calls are strictly prohibited
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    IF current_user NOT IN ('service_role', 'postgres') THEN
      RAISE EXCEPTION 'Authentication required: Anonymous callers cannot query user login info.'
        USING ERRCODE = '42501'; -- insufficient_privilege
    END IF;
    v_caller_role := 'service_role';
  ELSE
    -- Resolve caller's verified database role
    SELECT role::text INTO v_caller_role
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS NULL THEN
      RAISE EXCEPTION 'Unauthorized: Caller profile does not exist.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Clean and validate input parameter
  v_clean_identifier := TRIM(p_identifier);
  IF v_clean_identifier IS NULL OR v_clean_identifier = '' THEN
    RETURN NULL;
  END IF;

  -- B. Resolve target profile (restricted lookup: by university_code, email, or id)
  -- Note: Do NOT match against national_id or phone_number to prevent secondary enumeration
  SELECT 
    id,
    email, 
    role, 
    full_name,
    student_group,
    registration_status, 
    is_approved
  INTO v_profile
  FROM public.profiles
  WHERE LOWER(university_code) = LOWER(v_clean_identifier)
     OR LOWER(email) = LOWER(v_clean_identifier)
     OR id::text = v_clean_identifier
  LIMIT 1;

  IF v_profile IS NULL THEN
    RETURN NULL;
  END IF;

  -- C. Enforce Object-Level Authorization
  -- 1) 'super_admin' and 'service_role': permitted for any account
  -- 2) 'leader': permitted for student accounts or their own account
  -- 3) 'student' and 'evaluating_doctor': strictly restricted to their OWN account (id = v_caller_id)
  IF v_caller_role IN ('service_role', 'super_admin') THEN
    NULL; -- Authorized
  ELSIF v_caller_role = 'leader' THEN
    IF v_profile.id <> v_caller_id AND v_profile.role <> 'student' THEN
      RAISE EXCEPTION 'Permission denied: Leaders can only query student accounts.'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    IF v_profile.id <> v_caller_id THEN
      RAISE EXCEPTION 'Permission denied: Users can only query their own account information.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- D. Data Minimization: return only essential sanitized metadata (no national_id, phone, rejection_reason, etc.)
  RETURN jsonb_build_object(
    'id', v_profile.id,
    'email', v_profile.email,
    'role', v_profile.role,
    'full_name', v_profile.full_name,
    'student_group', v_profile.student_group,
    'registration_status', v_profile.registration_status,
    'is_approved', v_profile.is_approved
  );
END;
$$;

-- 4. Re-affirm explicit execute grants
REVOKE ALL ON FUNCTION public.get_user_login_info(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_login_info(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_login_info(TEXT) TO authenticated, service_role;
