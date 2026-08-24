-- ============================================================================
-- Migration: 20260824_student_admin_management_and_version_tracking.sql
-- Description:
-- 1. Creates public.user_app_versions table for tracking client app versions per platform
-- 2. Implements atomic RPC report_user_app_version
-- 3. Implements high-performance batch overview RPC get_admin_students_overview (Platform-Aware)
-- 4. Implements get_admin_student_full_profile with strict role-based data masking
-- 5. Enables Realtime on user_app_versions and configures RLS
-- ============================================================================

-- 1. Create user_app_versions table
CREATE TABLE IF NOT EXISTS public.user_app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform TEXT NOT NULL DEFAULT 'android', -- 'android', 'web', 'ios'
    version_name TEXT NOT NULL DEFAULT '1.0.0',
    version_code INT NOT NULL DEFAULT 1,
    device_info TEXT, -- Clean device description (e.g. 'Android 14 (Samsung)', 'Chrome 122 / Windows', 'Safari / iOS')
    last_reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_app_versions_user_platform UNIQUE (user_id, platform)
);

-- 2. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_app_versions_user ON public.user_app_versions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_app_versions_platform_code ON public.user_app_versions(platform, version_code);

-- 3. Set Replica Identity Full for complete Realtime payload broadcast
ALTER TABLE public.user_app_versions REPLICA IDENTITY FULL;

-- 4. Enable RLS
ALTER TABLE public.user_app_versions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies safely
DROP POLICY IF EXISTS "user_app_versions_select_policy" ON public.user_app_versions;
DROP POLICY IF EXISTS "user_app_versions_insert_self" ON public.user_app_versions;
DROP POLICY IF EXISTS "user_app_versions_update_self" ON public.user_app_versions;
DROP POLICY IF EXISTS "user_app_versions_delete_admin" ON public.user_app_versions;

-- A) SELECT Policy: Users can view own version, Staff (super_admin, leader) can view all
CREATE POLICY "user_app_versions_select_policy" ON public.user_app_versions
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text IN ('super_admin', 'leader')
        )
    );

-- B) INSERT Policy: Users can only report their own version
CREATE POLICY "user_app_versions_insert_self" ON public.user_app_versions
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- C) UPDATE Policy: Users can only update their own version
CREATE POLICY "user_app_versions_update_self" ON public.user_app_versions
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- D) DELETE Policy: Super admin only
CREATE POLICY "user_app_versions_delete_admin" ON public.user_app_versions
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text = 'super_admin'
        )
    );

-- Drop functions before replacing signatures
DROP FUNCTION IF EXISTS public.report_user_app_version(TEXT, TEXT, INT, TEXT);
DROP FUNCTION IF EXISTS public.get_admin_students_overview();
DROP FUNCTION IF EXISTS public.get_admin_student_full_profile(UUID);

-- 5. RPC to report client app version securely
CREATE OR REPLACE FUNCTION public.report_user_app_version(
    p_platform TEXT,
    p_version_name TEXT,
    p_version_code INT,
    p_device_info TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_clean_platform TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN;
    END IF;

    v_clean_platform := LOWER(TRIM(COALESCE(p_platform, 'android')));

    INSERT INTO public.user_app_versions (
        user_id,
        platform,
        version_name,
        version_code,
        device_info,
        last_reported_at,
        updated_at
    )
    VALUES (
        v_user_id,
        v_clean_platform,
        COALESCE(p_version_name, '1.0.0'),
        COALESCE(p_version_code, 1),
        p_device_info,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id, platform)
    DO UPDATE SET
        version_name = EXCLUDED.version_name,
        version_code = EXCLUDED.version_code,
        device_info = COALESCE(EXCLUDED.device_info, public.user_app_versions.device_info),
        last_reported_at = NOW(),
        updated_at = NOW();
END;
$$;

-- 6. Batch RPC: get_admin_students_overview (Platform-Aware Version Comparison & Realtime Presence)
CREATE OR REPLACE FUNCTION public.get_admin_students_overview()
RETURNS TABLE (
    student_id UUID,
    full_name TEXT,
    university_code TEXT,
    email TEXT,
    phone_number TEXT,
    gpa NUMERIC,
    student_group TEXT,
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
    -- Verify caller authorization: Super Admin or Leader only
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
        COALESCE(p.student_group, 'A') AS student_group,
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
    LEFT JOIN public.user_presence up ON up.user_id = p.id
    LEFT JOIN latest_user_versions luv ON luv.user_id = p.id
    LEFT JOIN latest_platform_releases lpr ON lpr.platform = COALESCE(luv.platform, 'android')
    WHERE p.role::text = 'student'
    ORDER BY p.full_name ASC;
END;
$$;

-- 7. Full Admin Student Profile RPC (With strict privacy masking for Leaders vs Super Admin)
CREATE OR REPLACE FUNCTION public.get_admin_student_full_profile(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_result JSONB;
    v_profile RECORD;
    v_presence RECORD;
    v_version RECORD;
    v_today_shift RECORD;
    v_attendance_stats RECORD;
    v_rewards JSONB;
    v_penalties JSONB;
    v_evaluations JSONB;
    v_quizzes JSONB;
    v_cairo_today DATE;
BEGIN
    -- Verify caller authorization
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin and Leaders can access admin student profiles.';
    END IF;

    v_cairo_today := (NOW() AT TIME ZONE 'Africa/Cairo')::DATE;

    -- 1. Fetch Profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = p_student_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Student not found');
    END IF;

    -- 2. Fetch Presence
    SELECT
        COALESCE(is_online, false) AS is_online,
        COALESCE((is_online AND last_seen_at >= (NOW() - INTERVAL '2 minutes')), false) AS effective_is_online,
        COALESCE(last_seen_at, v_profile.updated_at, v_profile.created_at, NOW() - INTERVAL '1 day') AS last_seen_at
    INTO v_presence
    FROM public.user_presence
    WHERE user_id = p_student_id;

    -- 3. Fetch App Version
    SELECT
        uav.platform,
        uav.version_name,
        uav.version_code,
        uav.device_info,
        uav.last_reported_at,
        av.version_name AS latest_version_name,
        av.version_code AS latest_version_code,
        CASE
            WHEN uav.version_code IS NULL THEN 'unknown'
            WHEN av.version_code IS NULL THEN 'up_to_date'
            WHEN uav.version_code >= av.version_code THEN 'up_to_date'
            WHEN uav.version_code < av.minimum_supported_version OR av.force_update = true THEN 'force_update_required'
            ELSE 'outdated'
        END AS update_status
    INTO v_version
    FROM public.user_app_versions uav
    LEFT JOIN LATERAL (
        SELECT version_name, version_code, minimum_supported_version, force_update
        FROM public.app_versions
        WHERE platform = uav.platform AND is_active = true
        ORDER BY version_code DESC
        LIMIT 1
    ) av ON true
    WHERE uav.user_id = p_student_id
    ORDER BY uav.last_reported_at DESC
    LIMIT 1;

    -- 4. Today's Assignment from Roster
    SELECT
        d.name_ar AS department_name,
        s.name_ar AS shift_name,
        s.start_time,
        s.end_time,
        p_doc.full_name AS supervisor_doctor
    INTO v_today_shift
    FROM public.roster_entries re
    JOIN public.departments d ON d.id = re.department_id
    JOIN public.shifts s ON s.id = re.shift_id
    LEFT JOIN public.profiles p_doc ON p_doc.id = re.assigned_doctor_id
    WHERE re.student_id = p_student_id
      AND re.shift_date = v_cairo_today
    LIMIT 1;

    -- 5. Attendance Stats
    SELECT
        COUNT(*) AS total_records,
        COUNT(*) FILTER (WHERE status = 'present') AS present_count,
        COUNT(*) FILTER (WHERE status = 'late') AS late_count,
        COUNT(*) FILTER (WHERE status = 'absent') AS absent_count,
        MAX(check_in_time) AS last_check_in
    INTO v_attendance_stats
    FROM public.attendance
    WHERE student_id = p_student_id;

    -- 6. Rewards
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', da.id,
            'reason', da.reason,
            'points', da.points,
            'created_at', da.created_at,
            'status', da.status,
            'created_by_name', p_creator.full_name
        ) ORDER BY da.created_at DESC
    ), '[]'::jsonb)
    INTO v_rewards
    FROM public.disciplinary_actions da
    LEFT JOIN public.profiles p_creator ON p_creator.id = da.created_by
    WHERE da.student_id = p_student_id AND da.points > 0;

    -- 7. Penalties / Warnings
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', da.id,
            'reason', da.reason,
            'severity', da.severity,
            'points_deducted', da.points_deducted,
            'created_at', da.created_at,
            'status', da.status,
            'created_by_name', p_creator.full_name
        ) ORDER BY da.created_at DESC
    ), '[]'::jsonb)
    INTO v_penalties
    FROM public.disciplinary_actions da
    LEFT JOIN public.profiles p_creator ON p_creator.id = da.created_by
    WHERE da.student_id = p_student_id AND (da.points_deducted > 0 OR da.points < 0);

    -- 8. Clinical Evaluations
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', e.id,
            'score', e.score,
            'notes', e.notes,
            'created_at', e.created_at,
            'doctor_name', p_doc.full_name
        ) ORDER BY e.created_at DESC
    ), '[]'::jsonb)
    INTO v_evaluations
    FROM public.evaluations e
    LEFT JOIN public.profiles p_doc ON p_doc.id = e.evaluator_id
    WHERE e.student_id = p_student_id;

    -- 9. Quizzes
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', qa.id,
            'score', qa.score,
            'max_score', qa.max_score,
            'completed_at', qa.completed_at
        ) ORDER BY qa.completed_at DESC
    ), '[]'::jsonb)
    INTO v_quizzes
    FROM public.quiz_attempts qa
    WHERE qa.student_id = p_student_id;

    -- Build output JSON with privacy controls
    v_result := jsonb_build_object(
        'student_id', v_profile.id,
        'full_name', v_profile.full_name,
        'university_code', v_profile.university_code,
        'email', v_profile.email,
        'phone_number', v_profile.phone_number,
        'gpa', v_profile.gpa,
        'student_group', COALESCE(v_profile.student_group, 'A'),
        'registration_status', v_profile.registration_status,
        'is_approved', v_profile.is_approved,
        'avatar_url', v_profile.avatar_url,
        -- Sensitive data: masked for Leaders, visible only to Super Admin
        'national_id', CASE WHEN v_caller_role = 'super_admin' THEN v_profile.national_id ELSE '••••••••••••••' END,
        'residence_address', CASE WHEN v_caller_role = 'super_admin' THEN v_profile.residence_address ELSE 'محافظة مطروح' END,
        'emergency_contact', v_profile.emergency_contact,
        'created_at', v_profile.created_at,
        'presence', jsonb_build_object(
            'is_online', COALESCE(v_presence.is_online, false),
            'effective_is_online', COALESCE(v_presence.effective_is_online, false),
            'last_seen_at', COALESCE(v_presence.last_seen_at, v_profile.updated_at, NOW())
        ),
        'app_version', jsonb_build_object(
            'platform', COALESCE(v_version.platform, 'android'),
            'version_name', COALESCE(v_version.version_name, 'غير معروف'),
            'version_code', COALESCE(v_version.version_code, 0),
            'device_info', COALESCE(v_version.device_info, ''),
            'last_reported_at', v_version.last_reported_at,
            'latest_version_name', COALESCE(v_version.latest_version_name, ''),
            'latest_version_code', COALESCE(v_version.latest_version_code, 0),
            'update_status', COALESCE(v_version.update_status, 'unknown')
        ),
        'today_shift', CASE
            WHEN v_today_shift.department_name IS NOT NULL THEN jsonb_build_object(
                'department', v_today_shift.department_name,
                'shift', v_today_shift.shift_name,
                'start_time', v_today_shift.start_time,
                'end_time', v_today_shift.end_time,
                'supervisor', COALESCE(v_today_shift.supervisor_doctor, 'غير محدد')
            )
            ELSE jsonb_build_object('status', 'off', 'label', 'راحة')
        END,
        'attendance_stats', jsonb_build_object(
            'total', COALESCE(v_attendance_stats.total_records, 0),
            'present', COALESCE(v_attendance_stats.present_count, 0),
            'late', COALESCE(v_attendance_stats.late_count, 0),
            'absent', COALESCE(v_attendance_stats.absent_count, 0),
            'last_check_in', v_attendance_stats.last_check_in,
            'attendance_percentage', CASE
                WHEN COALESCE(v_attendance_stats.total_records, 0) > 0 THEN
                    ROUND((v_attendance_stats.present_count::NUMERIC / v_attendance_stats.total_records::NUMERIC) * 100, 1)
                ELSE 100.0
            END
        ),
        'rewards', v_rewards,
        'penalties', v_penalties,
        'evaluations', v_evaluations,
        'quizzes', v_quizzes,
        'server_now', NOW()
    );

    RETURN v_result;
END;
$$;

-- 8. Add user_app_versions to Supabase Realtime Publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'user_app_versions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_app_versions;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- 9. Grant Permissions
GRANT ALL ON public.user_app_versions TO postgres, service_role;
GRANT SELECT, INSERT, UPDATE ON public.user_app_versions TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_user_app_version(TEXT, TEXT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_students_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_student_full_profile(UUID) TO authenticated;
