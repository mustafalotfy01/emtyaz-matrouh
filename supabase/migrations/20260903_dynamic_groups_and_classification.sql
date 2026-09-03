-- ==============================================================================
-- MIGRATION: Dynamic Student Groups, Student Classification & GPA Management
-- Date: 2026-09-03
-- File: 20260903_dynamic_groups_and_classification.sql
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CLASSIFICATION ENUM TYPE
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'student_classification_type') THEN
        CREATE TYPE public.student_classification_type AS ENUM (
            'practical_strong',    -- شاطر عملي
            'theoretical_strong',  -- دحيح نظري
            'weak'                 -- ضعيف
        );
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. DYNAMIC STUDENT GROUPS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    supervisor_doctor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_student_groups_dept ON public.student_groups(department_id);
CREATE INDEX IF NOT EXISTS idx_student_groups_doctor ON public.student_groups(supervisor_doctor_id);
CREATE INDEX IF NOT EXISTS idx_student_groups_active ON public.student_groups(is_active) WHERE is_active = true;

-- ------------------------------------------------------------------------------
-- 3. PROFILES EXTENSIONS (Classification, Dynamic Group FK, Previous Experience)
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS student_classification public.student_classification_type DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS student_group_id UUID REFERENCES public.student_groups(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS previous_work_experience BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS previous_workplace TEXT,
    ADD COLUMN IF NOT EXISTS previous_work_department TEXT,
    ADD COLUMN IF NOT EXISTS previous_work_experience_details TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_student_group_id ON public.profiles(student_group_id);
CREATE INDEX IF NOT EXISTS idx_profiles_classification ON public.profiles(student_classification);
CREATE INDEX IF NOT EXISTS idx_profiles_prev_exp ON public.profiles(previous_work_experience);

-- Relax legacy CHECK constraint on student_group if it exists
DO $$
BEGIN
    ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_student_group_check;
    ALTER TABLE public.roster_entries DROP CONSTRAINT IF EXISTS roster_entries_preference_type_check;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- ------------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY ON student_groups
-- ------------------------------------------------------------------------------
ALTER TABLE public.student_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "student_groups_select_all" ON public.student_groups;
CREATE POLICY "student_groups_select_all" ON public.student_groups
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "student_groups_admin_insert" ON public.student_groups;
CREATE POLICY "student_groups_admin_insert" ON public.student_groups
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text = 'super_admin'
        )
    );

DROP POLICY IF EXISTS "student_groups_admin_update" ON public.student_groups;
CREATE POLICY "student_groups_admin_update" ON public.student_groups
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text = 'super_admin'
        )
    );

DROP POLICY IF EXISTS "student_groups_admin_delete" ON public.student_groups;
CREATE POLICY "student_groups_admin_delete" ON public.student_groups
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text = 'super_admin'
        )
    );

-- ------------------------------------------------------------------------------
-- 5. SECURE RPC: update_student_gpa (Super Admin Only, Strict 0.00 - 4.00 range)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_student_gpa(
    p_student_id UUID,
    p_new_gpa NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_rounded_gpa NUMERIC(4,2);
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role != 'super_admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin can modify student GPA.';
    END IF;

    IF p_new_gpa IS NULL OR p_new_gpa < 0.00 OR p_new_gpa > 4.00 THEN
        RAISE EXCEPTION 'Invalid GPA: Value must be between 0.00 and 4.00.';
    END IF;

    v_rounded_gpa := ROUND(p_new_gpa, 2);

    UPDATE public.profiles
    SET gpa = v_rounded_gpa,
        updated_at = NOW()
    WHERE id = p_student_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student with ID % not found.', p_student_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'gpa', v_rounded_gpa
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. SECURE RPC: update_student_classification (Super Admin Only)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_student_classification(
    p_student_id UUID,
    p_classification TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_class_val public.student_classification_type;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role != 'super_admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin can modify student classification.';
    END IF;

    IF p_classification NOT IN ('practical_strong', 'theoretical_strong', 'weak') THEN
        RAISE EXCEPTION 'Invalid classification. Allowed: practical_strong, theoretical_strong, weak.';
    END IF;

    v_class_val := p_classification::public.student_classification_type;

    UPDATE public.profiles
    SET student_classification = v_class_val,
        updated_at = NOW()
    WHERE id = p_student_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student with ID % not found.', p_student_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'classification', p_classification
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 7. SECURE RPC: create_student_group
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_student_group(
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_department_id UUID DEFAULT NULL,
    p_supervisor_doctor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_doctor_role TEXT;
    v_group_id UUID;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role != 'super_admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin can create student groups.';
    END IF;

    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Group name is required.';
    END IF;

    IF p_supervisor_doctor_id IS NOT NULL THEN
        SELECT role::text INTO v_doctor_role FROM public.profiles WHERE id = p_supervisor_doctor_id;
        IF v_doctor_role != 'evaluating_doctor' THEN
            RAISE EXCEPTION 'Supervisor doctor must have evaluating_doctor role.';
        END IF;
    END IF;

    INSERT INTO public.student_groups (
        name,
        description,
        department_id,
        supervisor_doctor_id,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        TRIM(p_name),
        TRIM(p_description),
        p_department_id,
        p_supervisor_doctor_id,
        true,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'group_id', v_group_id,
        'name', TRIM(p_name)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 8. SECURE RPC: update_student_group
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_student_group(
    p_group_id UUID,
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_department_id UUID DEFAULT NULL,
    p_supervisor_doctor_id UUID DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT true
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
    IF v_caller_role IS NULL OR v_caller_role != 'super_admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin can edit student groups.';
    END IF;

    IF p_supervisor_doctor_id IS NOT NULL THEN
        SELECT role::text INTO v_doctor_role FROM public.profiles WHERE id = p_supervisor_doctor_id;
        IF v_doctor_role != 'evaluating_doctor' THEN
            RAISE EXCEPTION 'Supervisor doctor must have evaluating_doctor role.';
        END IF;
    END IF;

    UPDATE public.student_groups
    SET name = TRIM(p_name),
        description = TRIM(p_description),
        department_id = p_department_id,
        supervisor_doctor_id = p_supervisor_doctor_id,
        is_active = COALESCE(p_is_active, true),
        updated_at = NOW()
    WHERE id = p_group_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Group with ID % not found.', p_group_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'group_id', p_group_id
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 9. SECURE RPC: assign_student_to_group & remove_student_from_group
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assign_student_to_group(
    p_student_id UUID,
    p_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_group RECORD;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient permissions to assign students.';
    END IF;

    SELECT * INTO v_group FROM public.student_groups WHERE id = p_group_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target group not found.';
    END IF;

    UPDATE public.profiles
    SET student_group_id = p_group_id,
        updated_at = NOW()
    WHERE id = p_student_id AND role = 'student';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student not found.';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'group_id', p_group_id,
        'group_name', v_group.name
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_student_from_group(
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient permissions.';
    END IF;

    UPDATE public.profiles
    SET student_group_id = NULL,
        updated_at = NOW()
    WHERE id = p_student_id AND role = 'student';

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 10. RPC: get_student_groups_summary
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_student_groups_summary()
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    department_id UUID,
    department_name TEXT,
    supervisor_doctor_id UUID,
    supervisor_doctor_name TEXT,
    student_count BIGINT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        sg.id,
        sg.name,
        sg.description,
        sg.department_id,
        d.name_ar AS department_name,
        sg.supervisor_doctor_id,
        p_doc.full_name AS supervisor_doctor_name,
        COUNT(p_std.id) AS student_count,
        sg.is_active,
        sg.created_at,
        sg.updated_at
    FROM public.student_groups sg
    LEFT JOIN public.departments d ON d.id = sg.department_id
    LEFT JOIN public.profiles p_doc ON p_doc.id = sg.supervisor_doctor_id
    LEFT JOIN public.profiles p_std ON p_std.student_group_id = sg.id AND p_std.role = 'student'
    GROUP BY
        sg.id,
        sg.name,
        sg.description,
        sg.department_id,
        d.name_ar,
        sg.supervisor_doctor_id,
        p_doc.full_name,
        sg.is_active,
        sg.created_at,
        sg.updated_at
    ORDER BY sg.created_at ASC;
$$;

-- ------------------------------------------------------------------------------
-- 11. BATCH RPC: get_admin_students_overview (Platform-Aware & Dynamic Groups)
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
    student_group TEXT,
    student_group_id UUID,
    group_name TEXT,
    student_classification TEXT,
    previous_work_experience BOOLEAN,
    previous_workplace TEXT,
    previous_work_department TEXT,
    department_id UUID,
    department_name TEXT,
    supervisor_doctor_name TEXT,
    registration_status TEXT,
    is_approved BOOLEAN,
    avatar_url TEXT,
    is_online BOOLEAN,
    effective_is_online BOOLEAN,
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
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role::text IN ('super_admin', 'leader')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin and Leaders can access student administration data.';
    END IF;

    RETURN QUERY
    WITH latest_platform_releases AS (
        SELECT DISTINCT ON (av.platform)
            av.platform,
            av.version_name,
            av.version_code,
            av.force_update,
            av.minimum_supported_version
        FROM public.app_versions av
        WHERE av.is_active = true
        ORDER BY av.platform, av.version_code DESC
    ),
    latest_user_versions AS (
        SELECT DISTINCT ON (uav.user_id)
            uav.user_id,
            uav.platform,
            uav.version_name,
            uav.version_code,
            uav.device_info,
            uav.last_reported_at
        FROM public.user_app_versions uav
        ORDER BY uav.user_id, uav.last_reported_at DESC
    )
    SELECT
        p.id AS student_id,
        p.full_name,
        COALESCE(p.university_code, '') AS university_code,
        p.email,
        COALESCE(p.phone_number, '') AS phone_number,
        p.gpa,
        COALESCE(sg.name, 'بدون جروب') AS student_group,
        p.student_group_id,
        sg.name AS group_name,
        p.student_classification::TEXT AS student_classification,
        COALESCE(p.previous_work_experience, false) AS previous_work_experience,
        p.previous_workplace,
        p.previous_work_department,
        sg.department_id,
        d.name_ar AS department_name,
        p_doc.full_name AS supervisor_doctor_name,
        COALESCE(p.registration_status, 'approved') AS registration_status,
        COALESCE(p.is_approved, true) AS is_approved,
        COALESCE(p.avatar_url, '') AS avatar_url,
        COALESCE(up.is_online, false) AS is_online,
        COALESCE((up.is_online AND up.last_seen_at >= (NOW() - INTERVAL '2 minutes')), false) AS effective_is_online,
        COALESCE(up.last_seen_at, p.updated_at, p.created_at, NOW() - INTERVAL '1 day') AS last_seen_at,
        COALESCE(luv.platform, 'android') AS app_platform,
        COALESCE(luv.version_name, '') AS installed_version_name,
        COALESCE(luv.version_code, 0) AS installed_version_code,
        COALESCE(luv.device_info, '') AS device_info,
        luv.last_reported_at AS version_reported_at,
        COALESCE(lpr.version_name, '') AS latest_platform_version_name,
        COALESCE(lpr.version_code, 0) AS latest_platform_version_code,
        CASE
            WHEN luv.version_code IS NULL OR luv.version_code = 0 THEN 'unknown'
            WHEN lpr.version_code IS NULL OR lpr.version_code = 0 THEN 'up_to_date'
            WHEN luv.version_code >= lpr.version_code THEN 'up_to_date'
            WHEN luv.version_code < lpr.minimum_supported_version OR lpr.force_update = true THEN 'force_update_required'
            ELSE 'outdated'
        END AS update_status,
        NOW() AS server_now
    FROM public.profiles p
    LEFT JOIN public.student_groups sg ON sg.id = p.student_group_id
    LEFT JOIN public.departments d ON d.id = sg.department_id
    LEFT JOIN public.profiles p_doc ON p_doc.id = sg.supervisor_doctor_id
    LEFT JOIN public.user_presence up ON up.user_id = p.id
    LEFT JOIN latest_user_versions luv ON luv.user_id = p.id
    LEFT JOIN latest_platform_releases lpr ON lpr.platform = luv.platform
    WHERE p.role = 'student'
    ORDER BY p.full_name ASC;
END;
$$;

-- ------------------------------------------------------------------------------
-- 12. UPDATE handle_new_user TRIGGER
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
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
    v_role := COALESCE(new.raw_user_meta_data->>'role', 'student');

    IF v_role IN ('super_admin', 'leader', 'evaluating_doctor') THEN
        v_status := 'approved';
        v_approved := true;
    ELSE
        v_status := COALESCE(new.raw_user_meta_data->>'registration_status', 'pending');
        v_approved := false;
    END IF;

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

    BEGIN
        v_children := (new.raw_user_meta_data->>'children_count')::INT;
    EXCEPTION WHEN OTHERS THEN
        v_children := 0;
    END;

    v_prev_exp := COALESCE((new.raw_user_meta_data->>'previous_work_experience')::BOOLEAN, false);
    v_workplace := NULLIF(TRIM(new.raw_user_meta_data->>'previous_workplace'), '');
    v_work_dept := NULLIF(TRIM(new.raw_user_meta_data->>'previous_work_department'), '');
    v_exp_details := NULLIF(TRIM(new.raw_user_meta_data->>'previous_work_experience_details'), '');

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
        new.raw_user_meta_data->>'national_id',
        COALESCE(new.raw_user_meta_data->>'gender', 'male'),
        COALESCE(new.raw_user_meta_data->>'marital_status', 'أعزب/عزباء'),
        COALESCE(v_children, 0),
        COALESCE((new.raw_user_meta_data->>'is_matrouh_resident')::BOOLEAN, true),
        COALESCE(new.raw_user_meta_data->>'emergency_contact', ''),
        COALESCE(new.raw_user_meta_data->>'residence_address', ''),
        v_lat,
        v_lng,
        v_role::user_role,
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
        full_name = EXCLUDED.full_name,
        university_code = EXCLUDED.university_code,
        phone_number = EXCLUDED.phone_number,
        national_id = COALESCE(EXCLUDED.national_id, public.profiles.national_id),
        gender = EXCLUDED.gender,
        marital_status = EXCLUDED.marital_status,
        children_count = EXCLUDED.children_count,
        is_matrouh_resident = EXCLUDED.is_matrouh_resident,
        emergency_contact = EXCLUDED.emergency_contact,
        residence_address = EXCLUDED.residence_address,
        latitude = COALESCE(EXCLUDED.latitude, public.profiles.latitude),
        longitude = COALESCE(EXCLUDED.longitude, public.profiles.longitude),
        role = EXCLUDED.role,
        registration_status = EXCLUDED.registration_status,
        is_approved = EXCLUDED.is_approved,
        previous_work_experience = EXCLUDED.previous_work_experience,
        previous_workplace = EXCLUDED.previous_workplace,
        previous_work_department = EXCLUDED.previous_work_department,
        previous_work_experience_details = EXCLUDED.previous_work_experience_details,
        updated_at = NOW();

    RETURN new;
EXCEPTION WHEN OTHERS THEN
    BEGIN
        INSERT INTO public.profiles (
            id,
            email,
            full_name,
            university_code,
            role,
            registration_status,
            is_approved,
            created_at,
            updated_at
        )
        VALUES (
            new.id,
            new.email,
            COALESCE(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
            COALESCE(new.raw_user_meta_data->>'university_code', 'STD-' || substring(new.id::text from 1 for 8)),
            'student'::user_role,
            'pending',
            false,
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN new;
END;
$$;

-- ------------------------------------------------------------------------------
-- 13. GRANTS
-- ------------------------------------------------------------------------------
GRANT ALL ON public.student_groups TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_student_gpa(UUID, NUMERIC) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_student_classification(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_student_group(TEXT, TEXT, UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_student_group(UUID, TEXT, TEXT, UUID, UUID, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assign_student_to_group(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.remove_student_from_group(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_student_groups_summary() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_admin_students_overview() TO authenticated, service_role;
