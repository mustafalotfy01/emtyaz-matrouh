-- ==============================================================================
-- MIGRATION: Secure Auth New User Trigger (SEC-SWEEP-01 Remediation)
-- Date: 2026-09-10
-- File: 20260910_secure_handle_new_user_trigger.sql
-- Reason: Fix Critical Security Vulnerability (SEC-SWEEP-01):
--   1. Eliminate client-side role injection during auth.signUp().
--   2. Explicitly and unconditionally force:
--      - role := 'student'
--      - registration_status := 'pending'
--      - is_approved := false
--   3. Completely ignore any client-supplied role, registration_status, or is_approved
--      in raw_user_meta_data.
--   4. Preserve legitimate profile creation and safe registration metadata.
--   5. Maintain SECURITY DEFINER with fixed search_path = public, pg_temp.
-- ==============================================================================

-- 1. Redefine public.handle_new_user() with authoritative server-side role assignment
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_role public.user_role;
    v_status TEXT;
    v_approved BOOLEAN;
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    v_children INT;
    v_prev_exp BOOLEAN;
    v_workplace TEXT;
    v_work_dept TEXT;
    v_exp_details TEXT;
BEGIN
    -- SECURITY HARDENING (SEC-SWEEP-01):
    -- All newly registered users through auth.signUp MUST be assigned the 'student' role,
    -- 'pending' registration status, and is_approved = false.
    -- Client-supplied values in raw_user_meta_data (e.g. role = 'super_admin', 'leader',
    -- 'evaluating_doctor', registration_status = 'approved', is_approved = true)
    -- are COMPLETELY IGNORED.
    v_role := 'student'::public.user_role;
    v_status := 'pending';
    v_approved := false;

    -- Safely parse geographic coordinates
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

    -- Safely parse children count
    BEGIN
        v_children := (new.raw_user_meta_data->>'children_count')::INT;
    EXCEPTION WHEN OTHERS THEN
        v_children := 0;
    END;

    -- Safe registration metadata
    v_prev_exp := COALESCE((new.raw_user_meta_data->>'previous_work_experience')::BOOLEAN, false);
    v_workplace := NULLIF(TRIM(new.raw_user_meta_data->>'previous_workplace'), '');
    v_work_dept := NULLIF(TRIM(new.raw_user_meta_data->>'previous_work_department'), '');
    v_exp_details := NULLIF(TRIM(new.raw_user_meta_data->>'previous_work_experience_details'), '');

    -- Insert authoritative profile row
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
        role,
        registration_status,
        is_approved,
        previous_work_experience,
        previous_workplace,
        previous_work_department,
        previous_work_experience_details,
        created_at,
        updated_at
    )
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'full_name', 'طالب جديد'),
        COALESCE(new.raw_user_meta_data->>'university_code', 'STD-' || substring(new.id::text from 1 for 8)),
        COALESCE(new.raw_user_meta_data->>'phone_number', ''),
        NULLIF(TRIM(new.raw_user_meta_data->>'national_id'), ''),
        COALESCE(new.raw_user_meta_data->>'gender', 'male'),
        COALESCE(new.raw_user_meta_data->>'marital_status', 'أعزب/عزباء'),
        v_children,
        COALESCE((new.raw_user_meta_data->>'is_matrouh_resident')::BOOLEAN, true),
        COALESCE(new.raw_user_meta_data->>'emergency_contact', ''),
        COALESCE(new.raw_user_meta_data->>'residence_address', 'مطروح'),
        v_lat,
        v_lng,
        v_role,
        v_status,
        v_approved,
        v_prev_exp,
        v_workplace,
        v_work_dept,
        v_exp_details,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        updated_at = NOW();

    RETURN new;
END;
$$;

-- 2. Ensure the trigger on auth.users is properly attached
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
