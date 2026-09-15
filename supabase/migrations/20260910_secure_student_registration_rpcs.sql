-- ==============================================================================
-- MIGRATION: Secure Student Registration RPCs & Prevent Unauthorized Approvals
-- Date: 2026-09-10
-- File: 20260910_secure_student_registration_rpcs.sql
-- Reason: Fix Critical Security Vulnerability (Item 6):
--   1. Revoke EXECUTE from 'anon' and 'public' on registration approval/rejection RPCs.
--   2. Grant EXECUTE only to 'authenticated' and 'service_role'.
--   3. Enforce server-side authentication (auth.uid()) and caller role authorization:
--      - Only 'super_admin', 'leader', and 'service_role' can approve, reject, or reset registrations.
--      - 'student' and 'evaluating_doctor' calls are strictly rejected with 42501 (insufficient_privilege).
--   4. Prevent reviewer identity spoofing:
--      - Automatically bind reviewed_by to the caller's verified auth.uid().
--   5. Target-Role Protection:
--      - Enforce target.role = 'student'. Non-student accounts (admin, doctor, leader) cannot be targeted.
--   6. Set secure search_path (public, auth, pg_temp) to eliminate search path vulnerabilities.
-- ==============================================================================

-- 1. Revoke public/anon privileges from all three registration RPCs
REVOKE ALL ON FUNCTION public.approve_student_registration(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_student_registration(TEXT, TEXT) FROM anon;

REVOKE ALL ON FUNCTION public.reject_student_registration(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_student_registration(TEXT, TEXT, TEXT) FROM anon;

REVOKE ALL ON FUNCTION public.return_student_to_pending(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.return_student_to_pending(TEXT, TEXT) FROM anon;

-- 2. Grant execute only to authenticated users and service_role
GRANT EXECUTE ON FUNCTION public.approve_student_registration(TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_student_registration(TEXT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.return_student_to_pending(TEXT, TEXT) TO authenticated, service_role;

-- 3. Replace approve_student_registration with verified authorization & target protection
CREATE OR REPLACE FUNCTION public.approve_student_registration(
  p_student_id TEXT,
  p_reviewer_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role TEXT;
  v_effective_reviewer TEXT;
  v_clean_student_id TEXT;
  v_target_profile RECORD;
BEGIN
  -- A. Enforce Caller Authentication
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    IF current_user NOT IN ('service_role', 'postgres') THEN
      RAISE EXCEPTION 'Authentication required: Anonymous callers cannot approve registrations.'
        USING ERRCODE = '42501'; -- insufficient_privilege
    END IF;
    v_caller_role := 'service_role';
    v_effective_reviewer := COALESCE(TRIM(p_reviewer_id), 'service_role');
  ELSE
    -- Resolve caller's verified database role
    SELECT role::text INTO v_caller_role
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS NULL THEN
      RAISE EXCEPTION 'Unauthorized: Caller profile does not exist.'
        USING ERRCODE = '42501';
    END IF;

    -- Anti-spoofing: bind reviewer identity to caller's real verified ID
    v_effective_reviewer := v_caller_id::text;
  END IF;

  -- B. Enforce Caller Authorization: Only super_admin, leader, or service_role
  IF v_caller_role NOT IN ('super_admin', 'leader', 'service_role') THEN
    RAISE EXCEPTION 'Permission denied: Only administrators and leaders can approve student registrations.'
      USING ERRCODE = '42501';
  END IF;

  -- C. Validate Target Identifier
  v_clean_student_id := TRIM(p_student_id);
  IF v_clean_student_id IS NULL OR v_clean_student_id = '' THEN
    RAISE EXCEPTION 'Invalid target: Student identifier cannot be empty.'
      USING ERRCODE = '22023'; -- invalid_parameter_value
  END IF;

  -- D. Resolve Target Profile
  SELECT id, role, registration_status, is_approved
  INTO v_target_profile
  FROM public.profiles
  WHERE id::text = v_clean_student_id
     OR university_code = v_clean_student_id
     OR LOWER(email) = LOWER(v_clean_student_id)
  LIMIT 1;

  IF v_target_profile IS NULL THEN
    RETURN false; -- Student not found
  END IF;

  -- E. Target-Role Protection: Prevent modifying staff / doctor / admin accounts
  IF v_target_profile.role <> 'student' THEN
    RAISE EXCEPTION 'Permission denied: Registration status can only be modified for student accounts (target role: %).', v_target_profile.role
      USING ERRCODE = '42501';
  END IF;

  -- F. Apply Atomic State Transition
  UPDATE public.profiles
  SET 
    registration_status = 'approved',
    is_approved = true,
    reviewed_by = v_effective_reviewer,
    reviewed_at = NOW(),
    rejection_reason = NULL,
    updated_at = NOW()
  WHERE id = v_target_profile.id;

  RETURN true;
END;
$$;

-- 4. Replace reject_student_registration with verified authorization & target protection
CREATE OR REPLACE FUNCTION public.reject_student_registration(
  p_student_id TEXT,
  p_reason TEXT DEFAULT 'غير مستوفي للشروط',
  p_reviewer_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role TEXT;
  v_effective_reviewer TEXT;
  v_clean_student_id TEXT;
  v_clean_reason TEXT;
  v_target_profile RECORD;
BEGIN
  -- A. Enforce Caller Authentication
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    IF current_user NOT IN ('service_role', 'postgres') THEN
      RAISE EXCEPTION 'Authentication required: Anonymous callers cannot reject registrations.'
        USING ERRCODE = '42501';
    END IF;
    v_caller_role := 'service_role';
    v_effective_reviewer := COALESCE(TRIM(p_reviewer_id), 'service_role');
  ELSE
    SELECT role::text INTO v_caller_role
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS NULL THEN
      RAISE EXCEPTION 'Unauthorized: Caller profile does not exist.'
        USING ERRCODE = '42501';
    END IF;

    v_effective_reviewer := v_caller_id::text;
  END IF;

  -- B. Enforce Caller Authorization
  IF v_caller_role NOT IN ('super_admin', 'leader', 'service_role') THEN
    RAISE EXCEPTION 'Permission denied: Only administrators and leaders can reject student registrations.'
      USING ERRCODE = '42501';
  END IF;

  -- C. Validate Target Identifier
  v_clean_student_id := TRIM(p_student_id);
  IF v_clean_student_id IS NULL OR v_clean_student_id = '' THEN
    RAISE EXCEPTION 'Invalid target: Student identifier cannot be empty.'
      USING ERRCODE = '22023';
  END IF;

  -- D. Resolve Target Profile
  SELECT id, role, registration_status, is_approved
  INTO v_target_profile
  FROM public.profiles
  WHERE id::text = v_clean_student_id
     OR university_code = v_clean_student_id
     OR LOWER(email) = LOWER(v_clean_student_id)
  LIMIT 1;

  IF v_target_profile IS NULL THEN
    RETURN false;
  END IF;

  -- E. Target-Role Protection: Never reject an admin, doctor, or leader
  IF v_target_profile.role <> 'student' THEN
    RAISE EXCEPTION 'Permission denied: Registration status can only be modified for student accounts (target role: %).', v_target_profile.role
      USING ERRCODE = '42501';
  END IF;

  -- F. Sanitize reason string (limit to 500 characters)
  v_clean_reason := SUBSTRING(TRIM(COALESCE(p_reason, 'غير مستوفي للشروط')), 1, 500);
  IF v_clean_reason = '' THEN
    v_clean_reason := 'غير مستوفي للشروط';
  END IF;

  -- G. Apply Atomic State Transition
  UPDATE public.profiles
  SET 
    registration_status = 'rejected',
    is_approved = false,
    reviewed_by = v_effective_reviewer,
    reviewed_at = NOW(),
    rejection_reason = v_clean_reason,
    updated_at = NOW()
  WHERE id = v_target_profile.id;

  RETURN true;
END;
$$;

-- 5. Replace return_student_to_pending with verified authorization & target protection
CREATE OR REPLACE FUNCTION public.return_student_to_pending(
  p_student_id TEXT,
  p_reviewer_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role TEXT;
  v_effective_reviewer TEXT;
  v_clean_student_id TEXT;
  v_target_profile RECORD;
BEGIN
  -- A. Enforce Caller Authentication
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    IF current_user NOT IN ('service_role', 'postgres') THEN
      RAISE EXCEPTION 'Authentication required: Anonymous callers cannot reset registration status.'
        USING ERRCODE = '42501';
    END IF;
    v_caller_role := 'service_role';
    v_effective_reviewer := COALESCE(TRIM(p_reviewer_id), 'service_role');
  ELSE
    SELECT role::text INTO v_caller_role
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS NULL THEN
      RAISE EXCEPTION 'Unauthorized: Caller profile does not exist.'
        USING ERRCODE = '42501';
    END IF;

    v_effective_reviewer := v_caller_id::text;
  END IF;

  -- B. Enforce Caller Authorization
  IF v_caller_role NOT IN ('super_admin', 'leader', 'service_role') THEN
    RAISE EXCEPTION 'Permission denied: Only administrators and leaders can reset student registrations.'
      USING ERRCODE = '42501';
  END IF;

  -- C. Validate Target Identifier
  v_clean_student_id := TRIM(p_student_id);
  IF v_clean_student_id IS NULL OR v_clean_student_id = '' THEN
    RAISE EXCEPTION 'Invalid target: Student identifier cannot be empty.'
      USING ERRCODE = '22023';
  END IF;

  -- D. Resolve Target Profile
  SELECT id, role, registration_status, is_approved
  INTO v_target_profile
  FROM public.profiles
  WHERE id::text = v_clean_student_id
     OR university_code = v_clean_student_id
     OR LOWER(email) = LOWER(v_clean_student_id)
  LIMIT 1;

  IF v_target_profile IS NULL THEN
    RETURN false;
  END IF;

  -- E. Target-Role Protection: Never reset a staff or admin account
  IF v_target_profile.role <> 'student' THEN
    RAISE EXCEPTION 'Permission denied: Registration status can only be modified for student accounts (target role: %).', v_target_profile.role
      USING ERRCODE = '42501';
  END IF;

  -- F. Apply Atomic State Transition
  UPDATE public.profiles
  SET 
    registration_status = 'pending',
    is_approved = false,
    reviewed_by = v_effective_reviewer,
    reviewed_at = NOW(),
    rejection_reason = NULL,
    updated_at = NOW()
  WHERE id = v_target_profile.id;

  RETURN true;
END;
$$;

-- 6. Re-affirm explicit execute grants
REVOKE ALL ON FUNCTION public.approve_student_registration(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_student_registration(TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.approve_student_registration(TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reject_student_registration(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_student_registration(TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.reject_student_registration(TEXT, TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.return_student_to_pending(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.return_student_to_pending(TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.return_student_to_pending(TEXT, TEXT) TO authenticated, service_role;
