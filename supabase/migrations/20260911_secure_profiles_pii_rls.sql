-- ==============================================================================
-- MIGRATION: Remediate SEC-SWEEP-02 (Profiles PII Exposure via RLS)
-- Date: 2026-09-11
-- File: 20260911_secure_profiles_pii_rls.sql
-- Reason: Remediate SEC-SWEEP-02 (HIGH - CVSS 7.5):
--   1. Restrict public.profiles SELECT access so students can ONLY SELECT their own profile (auth.uid() = id).
--   2. Allow authorized staff (super_admin, leader, evaluating_doctor) and system roles (service_role, postgres) to read profiles.
--   3. Create a secure, sanitized RPC public.get_available_peers() for student peer selection / group preference
--      workflows that exposes ONLY non-sensitive directory columns (id, full_name, university_code, avatar_url, gender, student_group_id)
--      and NEVER leaks sensitive PII (national_id, phone_number, residence_address, emergency_contact, latitude, longitude, gpa, marital_status, etc.).
-- ==============================================================================

-- 1. Ensure get_auth_role() has explicit search_path and cannot be hijacked
CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    (SELECT role::text FROM public.profiles WHERE id = auth.uid()),
    'student'
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_auth_role() TO authenticated, service_role;

-- 2. Drop the overly permissive SELECT policy
DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "Profiles read" ON public.profiles;

-- 3. Recreate the hardened SELECT policy on public.profiles
-- Invariants:
-- - Anonymous callers (anon) get ZERO rows.
-- - Students can ONLY read their own profile row (auth.uid() = id).
-- - Staff (super_admin, leader, evaluating_doctor) retain full access to manage & evaluate students.
-- - Service role and postgres maintain administrative access.
CREATE POLICY "profiles_select_authenticated" ON public.profiles
    FOR SELECT
    TO authenticated, service_role
    USING (
        auth.uid() = id
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
        OR current_user IN ('service_role', 'postgres')
    );

-- 4. Create sanitized peer directory RPC for student grouping / peer discovery
CREATE OR REPLACE FUNCTION public.get_available_peers()
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    university_code TEXT,
    avatar_url TEXT,
    gender TEXT,
    student_group_id UUID
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT 
        p.id,
        p.full_name,
        p.university_code,
        p.avatar_url,
        p.gender,
        p.student_group_id
    FROM public.profiles p
    WHERE p.role = 'student'
      AND (p.is_approved = true OR p.registration_status = 'approved')
      AND (auth.uid() IS NULL OR p.id <> auth.uid())
    ORDER BY p.full_name ASC;
$$;

-- 5. Set permissions on the sanitized RPC
REVOKE ALL ON FUNCTION public.get_available_peers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_available_peers() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_available_peers() TO authenticated, service_role;
