-- ==============================================================================
-- MIGRATION: Fix Student Groups Update RPC & RLS Permissions
-- Date: 2026-09-11
-- File: 20260911_fix_student_groups_update_and_rls.sql
-- ==============================================================================

-- 1. Hardened & Flexible update_student_group RPC
CREATE OR REPLACE FUNCTION public.update_student_group(
    p_group_id UUID,
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_department_id UUID DEFAULT NULL,
    p_supervisor_doctor_id UUID DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_doctor_role TEXT;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader', 'admin') THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient permissions to edit student groups.';
    END IF;

    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Group name cannot be empty.';
    END IF;

    IF p_supervisor_doctor_id IS NOT NULL THEN
        SELECT role::text INTO v_doctor_role FROM public.profiles WHERE id = p_supervisor_doctor_id;
        IF v_doctor_role IS NULL OR v_doctor_role NOT IN ('evaluating_doctor', 'doctor') THEN
            RAISE EXCEPTION 'Supervisor doctor must have evaluating_doctor role.';
        END IF;
    END IF;

    UPDATE public.student_groups
    SET name = TRIM(p_name),
        description = CASE WHEN p_description IS NOT NULL THEN TRIM(p_description) ELSE description END,
        department_id = CASE WHEN p_department_id IS NOT NULL THEN p_department_id ELSE department_id END,
        supervisor_doctor_id = CASE WHEN p_supervisor_doctor_id IS NOT NULL THEN p_supervisor_doctor_id ELSE supervisor_doctor_id END,
        is_active = COALESCE(p_is_active, is_active),
        updated_at = NOW()
    WHERE id = p_group_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Group with ID % not found.', p_group_id;
    END IF;

    -- Automatically sync the updated group name in student profiles
    UPDATE public.profiles
    SET student_group = TRIM(p_name),
        updated_at = NOW()
    WHERE student_group_id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'group_id', p_group_id,
        'name', TRIM(p_name)
    );
END;
$$;

-- 2. Update Row-Level Security (RLS) policies for student_groups
ALTER TABLE public.student_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "student_groups_select_all" ON public.student_groups;
CREATE POLICY "student_groups_select_all" ON public.student_groups
    FOR SELECT
    TO authenticated, service_role
    USING (true);

DROP POLICY IF EXISTS "student_groups_admin_insert" ON public.student_groups;
CREATE POLICY "student_groups_admin_insert" ON public.student_groups
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text IN ('super_admin', 'leader', 'admin')
        )
    );

DROP POLICY IF EXISTS "student_groups_admin_update" ON public.student_groups;
CREATE POLICY "student_groups_admin_update" ON public.student_groups
    FOR UPDATE
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text IN ('super_admin', 'leader', 'admin')
        )
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text IN ('super_admin', 'leader', 'admin')
        )
    );

DROP POLICY IF EXISTS "student_groups_admin_delete" ON public.student_groups;
CREATE POLICY "student_groups_admin_delete" ON public.student_groups
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text IN ('super_admin', 'leader', 'admin')
        )
    );

GRANT EXECUTE ON FUNCTION public.update_student_group(UUID, TEXT, TEXT, UUID, UUID, BOOLEAN) TO authenticated, service_role;
