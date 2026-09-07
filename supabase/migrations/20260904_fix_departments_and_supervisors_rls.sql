-- ==============================================================================
-- MIGRATION: Fix Departments and Department Supervisors RLS Policies
-- Date: 2026-09-04
-- Reason: Fix PostgrestException 42501 (new row violates row-level security policy for table departments)
--         Allow Super Admins and Leaders to insert, update, and delete departments.
-- ==============================================================================

-- 1. Ensure Table Structure & Extensions
ALTER TABLE IF EXISTS public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.department_supervisors ENABLE ROW LEVEL SECURITY;

-- 2. Clean Up Existing Old Policies on departments
DROP POLICY IF EXISTS "Public departments read" ON public.departments;
DROP POLICY IF EXISTS "departments_read_all" ON public.departments;
DROP POLICY IF EXISTS "departments_admin_manage" ON public.departments;
DROP POLICY IF EXISTS "departments_leader_admin_all" ON public.departments;
DROP POLICY IF EXISTS "departments_leader_admin_insert" ON public.departments;
DROP POLICY IF EXISTS "departments_leader_admin_update" ON public.departments;
DROP POLICY IF EXISTS "departments_leader_admin_delete" ON public.departments;

-- 3. Departments Policies:
-- (A) Read: Open for all authenticated and anon users
CREATE POLICY "departments_read_all" ON public.departments
    FOR SELECT
    USING (true);

-- (B) Insert: Super Admin and Leaders
CREATE POLICY "departments_leader_admin_insert" ON public.departments
    FOR INSERT
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

-- (C) Update: Super Admin and Leaders
CREATE POLICY "departments_leader_admin_update" ON public.departments
    FOR UPDATE
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

-- (D) Delete: Super Admin and Leaders
CREATE POLICY "departments_leader_admin_delete" ON public.departments
    FOR DELETE
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

-- 4. Clean Up & Recreate Policies for department_supervisors
DROP POLICY IF EXISTS "dept_sup_admin_manage" ON public.department_supervisors;
DROP POLICY IF EXISTS "dept_sup_student_read" ON public.department_supervisors;
DROP POLICY IF EXISTS "dept_sup_read_all" ON public.department_supervisors;
DROP POLICY IF EXISTS "dept_sup_manage_all" ON public.department_supervisors;

-- (A) Read supervisors: Open for all
CREATE POLICY "dept_sup_read_all" ON public.department_supervisors
    FOR SELECT
    USING (true);

-- (B) Manage supervisors: Super Admin and Leaders
CREATE POLICY "dept_sup_manage_all" ON public.department_supervisors
    FOR ALL
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

-- 5. Grant Permissions to roles
GRANT ALL ON public.departments TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.department_supervisors TO postgres, anon, authenticated, service_role;
