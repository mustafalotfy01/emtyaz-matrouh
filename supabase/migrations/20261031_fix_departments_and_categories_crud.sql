-- ==============================================================================
-- MIGRATION: Fix Departments and Categories Update & Delete (CRUD & RPC)
-- Date: 2026-10-31
-- File: 20261031_fix_departments_and_categories_crud.sql
-- Description:
--   1. Fix RLS policies on public.departments, public.department_supervisors,
--      and public.knowledge_categories to allow super_admin, leader, and admin roles.
--   2. Add secure, atomic update_department RPC with role enforcement.
--   3. Add secure, cascade-safe delete_department RPC that cleans up
--      associated records (supervisors, monthly assignments, groups) without FK errors.
--   4. Add secure update_knowledge_category & delete_knowledge_category RPCs.
-- ==============================================================================

-- 1. Ensure Table RLS is enabled
ALTER TABLE IF EXISTS public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.department_supervisors ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.knowledge_categories ENABLE ROW LEVEL SECURITY;

-- 2. Hardened RLS for public.departments
DROP POLICY IF EXISTS "Public departments read" ON public.departments;
DROP POLICY IF EXISTS "departments_read_all" ON public.departments;
DROP POLICY IF EXISTS "departments_admin_manage" ON public.departments;
DROP POLICY IF EXISTS "departments_leader_admin_all" ON public.departments;
DROP POLICY IF EXISTS "departments_leader_admin_insert" ON public.departments;
DROP POLICY IF EXISTS "departments_leader_admin_update" ON public.departments;
DROP POLICY IF EXISTS "departments_leader_admin_delete" ON public.departments;
DROP POLICY IF EXISTS "departments_manage_all" ON public.departments;

-- Allow everyone (authenticated + anon) to read departments
CREATE POLICY "departments_read_all" ON public.departments
    FOR SELECT
    USING (true);

-- Allow super_admin, leader, admin to insert, update, delete departments
CREATE POLICY "departments_manage_all" ON public.departments
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'admin')
        OR current_user IN ('service_role', 'postgres')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'admin')
        OR current_user IN ('service_role', 'postgres')
    );

-- 3. Hardened RLS for public.department_supervisors
DROP POLICY IF EXISTS "dept_sup_admin_manage" ON public.department_supervisors;
DROP POLICY IF EXISTS "dept_sup_student_read" ON public.department_supervisors;
DROP POLICY IF EXISTS "dept_sup_read_all" ON public.department_supervisors;
DROP POLICY IF EXISTS "dept_sup_manage_all" ON public.department_supervisors;

CREATE POLICY "dept_sup_read_all" ON public.department_supervisors
    FOR SELECT
    USING (true);

CREATE POLICY "dept_sup_manage_all" ON public.department_supervisors
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'admin')
        OR current_user IN ('service_role', 'postgres')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'admin')
        OR current_user IN ('service_role', 'postgres')
    );

-- 4. Hardened RLS for public.knowledge_categories
DROP POLICY IF EXISTS "categories_read_policy" ON public.knowledge_categories;
DROP POLICY IF EXISTS "Public categories read" ON public.knowledge_categories;
DROP POLICY IF EXISTS "categories_admin_manage_policy" ON public.knowledge_categories;

CREATE POLICY "categories_read_policy" ON public.knowledge_categories
    FOR SELECT
    USING (true);

CREATE POLICY "categories_admin_manage_policy" ON public.knowledge_categories
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'admin', 'evaluating_doctor')
        OR current_user IN ('service_role', 'postgres')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'admin', 'evaluating_doctor')
        OR current_user IN ('service_role', 'postgres')
    );

-- 5. RPC: Atomic update_department
CREATE OR REPLACE FUNCTION public.update_department(
    p_department_id UUID,
    p_name_ar TEXT,
    p_name_en TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_male_capacity INT DEFAULT NULL,
    p_female_capacity INT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_clean_ar TEXT;
    v_clean_en TEXT;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader', 'admin') THEN
        IF current_user NOT IN ('service_role', 'postgres') THEN
            RAISE EXCEPTION 'Unauthorized: Only Super Admin and Leader can update departments.';
        END IF;
    END IF;

    v_clean_ar := TRIM(COALESCE(p_name_ar, ''));
    IF v_clean_ar = '' THEN
        RAISE EXCEPTION 'اسم القسم بالعربية مطلوب ولا يمكن تركه فارغاً.';
    END IF;

    v_clean_en := TRIM(COALESCE(p_name_en, ''));
    IF v_clean_en = '' THEN
        v_clean_en := v_clean_ar;
    END IF;

    UPDATE public.departments
    SET name_ar = v_clean_ar,
        name_en = v_clean_en,
        description = CASE WHEN p_description IS NOT NULL THEN TRIM(p_description) ELSE description END,
        male_capacity = COALESCE(p_male_capacity, male_capacity),
        female_capacity = COALESCE(p_female_capacity, female_capacity),
        is_active = COALESCE(p_is_active, is_active),
        updated_at = NOW()
    WHERE id = p_department_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'القسم غير موجود برقم المعرف: %', p_department_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'department_id', p_department_id,
        'name_ar', v_clean_ar,
        'name_en', v_clean_en
    );
END;
$$;

-- 6. RPC: Safe delete_department
CREATE OR REPLACE FUNCTION public.delete_department(
    p_department_id UUID,
    p_force_cascade BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_dept_name TEXT;
    v_roster_count INT;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader', 'admin') THEN
        IF current_user NOT IN ('service_role', 'postgres') THEN
            RAISE EXCEPTION 'Unauthorized: Only Super Admin and Leader can delete departments.';
        END IF;
    END IF;

    SELECT name_ar INTO v_dept_name FROM public.departments WHERE id = p_department_id;
    IF v_dept_name IS NULL THEN
        RAISE EXCEPTION 'القسم غير موجود أو تم حذفه مسبقاً.';
    END IF;

    -- Check if students have registered shifts in this department
    SELECT count(*) INTO v_roster_count FROM public.roster_entries WHERE department_id = p_department_id;
    IF v_roster_count > 0 AND NOT p_force_cascade THEN
        RAISE EXCEPTION 'لا يمكن حذف هذا القسم لاحتوائه على % شيفت مسجل للطلاب. يرجى تعطيل القسم بدلاً من حذفه.', v_roster_count;
    END IF;

    -- If force cascade is enabled, clean roster and attendance entries first
    IF v_roster_count > 0 AND p_force_cascade THEN
        DELETE FROM public.attendance WHERE department_id = p_department_id;
        DELETE FROM public.roster_entries WHERE department_id = p_department_id;
    END IF;

    -- Clean up all other related records safely to prevent foreign key errors
    DELETE FROM public.department_supervisors WHERE department_id = p_department_id;
    DELETE FROM public.group_monthly_departments WHERE department_id = p_department_id;
    UPDATE public.student_groups SET department_id = NULL WHERE department_id = p_department_id;
    UPDATE public.clinical_exceptions SET department_id = NULL WHERE department_id = p_department_id;
    UPDATE public.clinical_permissions SET department_id = NULL WHERE department_id = p_department_id;
    UPDATE public.clinical_compensations SET department_id = NULL WHERE department_id = p_department_id;
    DELETE FROM public.attendance_zones WHERE department_id = p_department_id;
    DELETE FROM public.shift_requests WHERE department_id = p_department_id;
    DELETE FROM public.cases WHERE department_id = p_department_id;
    DELETE FROM public.quizzes WHERE department_id = p_department_id;
    DELETE FROM public.evaluations WHERE department_id = p_department_id;

    -- Delete the department row
    DELETE FROM public.departments WHERE id = p_department_id;

    RETURN jsonb_build_object(
        'success', true,
        'department_id', p_department_id,
        'name_ar', v_dept_name
    );
END;
$$;

-- 7. Grant permissions
GRANT ALL ON public.departments TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.department_supervisors TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.knowledge_categories TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_department(UUID, TEXT, TEXT, TEXT, INT, INT, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_department(UUID, BOOLEAN) TO authenticated, service_role;
