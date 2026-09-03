-- ==============================================================================
-- MIGRATION: Group Monthly Departments, Group Architecture & Peer Preferences Cleanup
-- Date: 2026-09-03
-- File: 20260903_group_monthly_departments_and_peer_cleanup.sql
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. GROUP MONTHLY DEPARTMENTS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.group_monthly_departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.student_groups(id) ON DELETE CASCADE,
    department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
    year INT NOT NULL,
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_group_year_month UNIQUE (group_id, year, month)
);

CREATE INDEX IF NOT EXISTS idx_group_monthly_depts_lookup 
    ON public.group_monthly_departments(group_id, year, month);
CREATE INDEX IF NOT EXISTS idx_group_monthly_depts_dept 
    ON public.group_monthly_departments(department_id);

ALTER TABLE public.group_monthly_departments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "group_monthly_departments_select" ON public.group_monthly_departments;
CREATE POLICY "group_monthly_departments_select" ON public.group_monthly_departments
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "group_monthly_departments_admin_all" ON public.group_monthly_departments;
CREATE POLICY "group_monthly_departments_admin_all" ON public.group_monthly_departments
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role IN ('super_admin', 'leader')
        )
    );

GRANT ALL ON public.group_monthly_departments TO postgres, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 2. CREATE STUDENT GROUP RPC (NAME & DESCRIPTION ONLY)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_student_group(TEXT, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS public.create_student_group(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.create_student_group(
    p_name TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_new_id UUID;
BEGIN
    SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin and Leader can create student groups';
    END IF;

    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Group name is required';
    END IF;

    INSERT INTO public.student_groups (name, description, is_active)
    VALUES (TRIM(p_name), TRIM(p_description), true)
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. ASSIGN DOCTOR TO GROUP RPC (DIRECT LINKAGE TO EVALUATING DOCTOR)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.assign_doctor_to_group(UUID, UUID);

CREATE OR REPLACE FUNCTION public.assign_doctor_to_group(
    p_group_id UUID,
    p_doctor_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_doc_role TEXT;
    v_doc_name TEXT;
BEGIN
    SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin and Leader can assign doctors to groups';
    END IF;

    IF p_doctor_id IS NOT NULL THEN
        SELECT role, full_name INTO v_doc_role, v_doc_name FROM public.profiles WHERE id = p_doctor_id;
        IF v_doc_role IS NULL OR v_doc_role NOT IN ('evaluating_doctor', 'doctor') THEN
            RAISE EXCEPTION 'Invalid doctor: Profile must have role evaluating_doctor';
        END IF;
    END IF;

    UPDATE public.student_groups
    SET supervisor_doctor_id = p_doctor_id,
        updated_at = NOW()
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'group_id', p_group_id,
        'doctor_id', p_doctor_id,
        'doctor_name', v_doc_name
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. SET GROUP MONTHLY DEPARTMENT RPC (DOES NOT ASK FOR DOCTOR)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.set_group_monthly_department(UUID, UUID, INT, INT);

CREATE OR REPLACE FUNCTION public.set_group_monthly_department(
    p_group_id UUID,
    p_department_id UUID,
    p_year INT,
    p_month INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_dept_name TEXT;
    v_record RECORD;
BEGIN
    SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin and Leader can set monthly department assignments';
    END IF;

    IF p_month < 1 OR p_month > 12 THEN
        RAISE EXCEPTION 'Invalid month: % (must be 1-12)', p_month;
    END IF;

    SELECT name_ar INTO v_dept_name FROM public.departments WHERE id = p_department_id;
    IF v_dept_name IS NULL THEN
        RAISE EXCEPTION 'Department not found: %', p_department_id;
    END IF;

    INSERT INTO public.group_monthly_departments (group_id, department_id, year, month, updated_at)
    VALUES (p_group_id, p_department_id, p_year, p_month, NOW())
    ON CONFLICT (group_id, year, month)
    DO UPDATE SET
        department_id = EXCLUDED.department_id,
        updated_at = NOW()
    RETURNING * INTO v_record;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_record.id,
        'group_id', v_record.group_id,
        'department_id', v_record.department_id,
        'department_name', v_dept_name,
        'year', v_record.year,
        'month', v_record.month
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. GET GROUP MONTHLY TIMELINE RPC
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_group_monthly_timeline(UUID);

CREATE OR REPLACE FUNCTION public.get_group_monthly_timeline(
    p_group_id UUID
)
RETURNS TABLE (
    id UUID,
    group_id UUID,
    department_id UUID,
    department_name TEXT,
    year INT,
    month INT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        gmd.id,
        gmd.group_id,
        gmd.department_id,
        d.name_ar AS department_name,
        gmd.year,
        gmd.month,
        gmd.created_at,
        gmd.updated_at
    FROM public.group_monthly_departments gmd
    JOIN public.departments d ON d.id = gmd.department_id
    WHERE gmd.group_id = p_group_id
    ORDER BY gmd.year DESC, gmd.month DESC;
$$;

-- ------------------------------------------------------------------------------
-- 6. GET STUDENT GROUPS SUMMARY RPC (WITH CURRENT CAIRO MONTH AUTO RESOLUTION)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_student_groups_summary();
DROP FUNCTION IF EXISTS public.get_student_groups_summary(INT, INT);

CREATE OR REPLACE FUNCTION public.get_student_groups_summary(
    p_year INT DEFAULT NULL,
    p_month INT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    supervisor_doctor_id UUID,
    supervisor_doctor_name TEXT,
    current_month_department_id UUID,
    current_month_department_name TEXT,
    student_count BIGINT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_target_year INT;
    v_target_month INT;
    v_cairo_now TIMESTAMPTZ;
BEGIN
    v_cairo_now := timezone('Africa/Cairo', now());
    v_target_year := COALESCE(p_year, EXTRACT(YEAR FROM v_cairo_now)::INT);
    v_target_month := COALESCE(p_month, EXTRACT(MONTH FROM v_cairo_now)::INT);

    RETURN QUERY
    SELECT
        g.id,
        g.name,
        g.description,
        g.supervisor_doctor_id,
        doc.full_name AS supervisor_doctor_name,
        gmd.department_id AS current_month_department_id,
        d.name_ar AS current_month_department_name,
        COUNT(p.id) AS student_count,
        g.is_active,
        g.created_at,
        g.updated_at
    FROM public.student_groups g
    LEFT JOIN public.profiles doc ON doc.id = g.supervisor_doctor_id
    LEFT JOIN public.group_monthly_departments gmd 
        ON gmd.group_id = g.id 
        AND gmd.year = v_target_year 
        AND gmd.month = v_target_month
    LEFT JOIN public.departments d ON d.id = gmd.department_id
    LEFT JOIN public.profiles p ON p.student_group_id = g.id AND p.role = 'student'
    GROUP BY
        g.id,
        g.name,
        g.description,
        g.supervisor_doctor_id,
        doc.full_name,
        gmd.department_id,
        d.name_ar,
        g.is_active,
        g.created_at,
        g.updated_at
    ORDER BY g.created_at ASC;
END;
$$;

-- ------------------------------------------------------------------------------
-- 7. UPDATE GET_ADMIN_STUDENTS_OVERVIEW WITH DYNAMIC GROUP & MONTHLY DEPT
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_admin_students_overview();

CREATE OR REPLACE FUNCTION public.get_admin_students_overview()
RETURNS TABLE (
    student_id UUID,
    full_name TEXT,
    university_code TEXT,
    email TEXT,
    phone_number TEXT,
    gpa NUMERIC,
    student_classification public.student_classification_type,
    student_group_id UUID,
    group_name TEXT,
    supervisor_doctor_id UUID,
    supervisor_doctor_name TEXT,
    department_name TEXT,
    previous_work_experience BOOLEAN,
    previous_workplace TEXT,
    previous_work_department TEXT,
    previous_work_experience_details TEXT,
    registration_status TEXT,
    is_approved BOOLEAN,
    avatar_url TEXT,
    is_online BOOLEAN,
    last_seen_at TIMESTAMPTZ,
    app_platform TEXT,
    installed_version_name TEXT,
    installed_version_code INT,
    device_info TEXT,
    version_reported_at TIMESTAMPTZ,
    latest_platform_version_name TEXT,
    latest_platform_version_code INT,
    update_status TEXT,
    server_now TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cairo_now TIMESTAMPTZ;
    v_target_year INT;
    v_target_month INT;
BEGIN
    v_cairo_now := timezone('Africa/Cairo', now());
    v_target_year := EXTRACT(YEAR FROM v_cairo_now)::INT;
    v_target_month := EXTRACT(MONTH FROM v_cairo_now)::INT;

    RETURN QUERY
    SELECT
        p.id AS student_id,
        p.full_name,
        p.university_code,
        p.email,
        p.phone_number,
        p.gpa,
        p.student_classification,
        p.student_group_id,
        COALESCE(sg.name, p.student_group, 'بدون جروب') AS group_name,
        sg.supervisor_doctor_id,
        doc.full_name AS supervisor_doctor_name,
        COALESCE(cur_dept.name_ar, legacy_dept.name_ar, 'غير مخصص') AS department_name,
        COALESCE(p.previous_work_experience, false) AS previous_work_experience,
        p.previous_workplace,
        p.previous_work_department,
        p.previous_work_experience_details,
        p.registration_status,
        COALESCE(p.is_approved, false) AS is_approved,
        p.avatar_url,
        COALESCE(p.is_online, false) AS is_online,
        p.last_seen_at,
        uav.platform AS app_platform,
        uav.installed_version_name,
        uav.installed_version_code,
        uav.device_info,
        uav.updated_at AS version_reported_at,
        pav.version_name AS latest_platform_version_name,
        pav.version_code AS latest_platform_version_code,
        CASE
            WHEN uav.installed_version_code IS NULL OR pav.version_code IS NULL THEN 'unknown'
            WHEN uav.installed_version_code >= pav.version_code THEN 'up_to_date'
            WHEN pav.is_critical = true OR (pav.min_supported_version_code IS NOT NULL AND uav.installed_version_code < pav.min_supported_version_code) THEN 'critical'
            ELSE 'outdated'
        END AS update_status,
        NOW() AS server_now
    FROM public.profiles p
    LEFT JOIN public.student_groups sg ON sg.id = p.student_group_id
    LEFT JOIN public.profiles doc ON doc.id = sg.supervisor_doctor_id
    LEFT JOIN public.group_monthly_departments gmd 
        ON gmd.group_id = sg.id 
        AND gmd.year = v_target_year 
        AND gmd.month = v_target_month
    LEFT JOIN public.departments cur_dept ON cur_dept.id = gmd.department_id
    LEFT JOIN public.departments legacy_dept ON legacy_dept.id = sg.department_id
    LEFT JOIN public.user_app_versions uav ON uav.user_id = p.id
    LEFT JOIN public.platform_app_versions pav ON pav.platform = COALESCE(uav.platform, 'android') AND pav.is_active = true
    WHERE p.role = 'student'
    ORDER BY p.created_at DESC;
END;
$$;

-- ------------------------------------------------------------------------------
-- 8. GRANT RPC EXECUTION PERMISSIONS
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.create_student_group(TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assign_doctor_to_group(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_group_monthly_department(UUID, UUID, INT, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_group_monthly_timeline(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_student_groups_summary(INT, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_admin_students_overview() TO authenticated, service_role;
