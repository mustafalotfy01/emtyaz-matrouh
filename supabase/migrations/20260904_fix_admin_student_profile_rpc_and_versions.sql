-- 20260904_fix_admin_student_profile_rpc_and_versions.sql
-- Fixes relation name (app_versions instead of platform_app_versions)
-- and installs get_admin_student_full_profile and get_admin_students_overview with dynamic group support.

-- Drop existing functions to allow signature replacement
DROP FUNCTION IF EXISTS public.get_admin_students_overview();
DROP FUNCTION IF EXISTS public.get_admin_student_full_profile(UUID);

-- 1. Batch RPC: get_admin_students_overview
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
    student_classification TEXT,
    department_name TEXT,
    supervisor_doctor_name TEXT,
    previous_work_experience BOOLEAN,
    previous_workplace TEXT,
    previous_work_department TEXT,
    previous_work_experience_details TEXT,
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
        COALESCE(sg.name, 'بدون جروب') AS student_group,
        p.student_group_id,
        p.student_classification,
        dept.name_ar AS department_name,
        doc.full_name AS supervisor_doctor_name,
        COALESCE(p.previous_work_experience, false) AS previous_work_experience,
        p.previous_workplace,
        p.previous_work_department,
        p.previous_work_experience_details,
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
    LEFT JOIN public.departments dept ON dept.id = sg.current_department_id
    LEFT JOIN public.profiles doc ON doc.id = sg.supervisor_doctor_id
    LEFT JOIN public.user_presence up ON up.user_id = p.id
    LEFT JOIN latest_user_versions luv ON luv.user_id = p.id
    LEFT JOIN latest_platform_releases lpr ON lpr.platform = COALESCE(luv.platform, 'android')
    WHERE p.role::text = 'student'
    ORDER BY p.full_name ASC;
END;
$$;

-- 2. Full Admin Student Profile RPC
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
    v_group RECORD;
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

    -- 2. Fetch Group details
    SELECT
        sg.id,
        sg.name AS group_name,
        dept.name_ar AS department_name,
        doc.full_name AS supervisor_doctor_name
    INTO v_group
    FROM public.student_groups sg
    LEFT JOIN public.departments dept ON dept.id = sg.current_department_id
    LEFT JOIN public.profiles doc ON doc.id = sg.supervisor_doctor_id
    WHERE sg.id = v_profile.student_group_id;

    -- 3. Fetch Presence
    SELECT
        COALESCE(is_online, false) AS is_online,
        COALESCE((is_online AND last_seen_at >= (NOW() - INTERVAL '2 minutes')), false) AS effective_is_online,
        COALESCE(last_seen_at, v_profile.updated_at, v_profile.created_at, NOW() - INTERVAL '1 day') AS last_seen_at
    INTO v_presence
    FROM public.user_presence
    WHERE user_id = p_student_id;

    -- 4. Fetch App Version
    SELECT
        uav.platform,
        uav.version_name,
        uav.version_code,
        uav.device_info,
        uav.last_reported_at,
        av.version_name AS latest_version_name,
        av.version_code AS latest_version_code,
        CASE
            WHEN uav.version_code IS NULL OR uav.version_code = 0 THEN 'unknown'
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

    -- 5. Today's Assignment from Roster
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

    -- 6. Attendance Stats
    SELECT
        COUNT(*) AS total_records,
        COUNT(*) FILTER (WHERE status = 'present') AS present_count,
        COUNT(*) FILTER (WHERE status = 'late') AS late_count,
        COUNT(*) FILTER (WHERE status = 'absent') AS absent_count,
        MAX(check_in_time) AS last_check_in
    INTO v_attendance_stats
    FROM public.attendance
    WHERE student_id = p_student_id;

    -- 7. Rewards
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

    -- 8. Penalties
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
    INTO v_penalties
    FROM public.disciplinary_actions da
    LEFT JOIN public.profiles p_creator ON p_creator.id = da.created_by
    WHERE da.student_id = p_student_id AND da.points < 0;

    -- 9. Evaluations
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', de.id,
            'score', de.score,
            'notes', de.notes,
            'evaluated_at', de.evaluated_at,
            'doctor_name', p_evaluator.full_name
        ) ORDER BY de.evaluated_at DESC
    ), '[]'::jsonb)
    INTO v_evaluations
    FROM public.doctor_evaluations de
    LEFT JOIN public.profiles p_evaluator ON p_evaluator.id = de.doctor_id
    WHERE de.student_id = p_student_id;

    -- 10. Quizzes
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

    -- Build output JSON
    v_result := jsonb_build_object(
        'student_id', v_profile.id,
        'full_name', v_profile.full_name,
        'university_code', v_profile.university_code,
        'email', v_profile.email,
        'phone_number', v_profile.phone_number,
        'gpa', v_profile.gpa,
        'student_group', COALESCE(v_group.group_name, 'بدون جروب'),
        'student_group_id', v_profile.student_group_id,
        'group_name', COALESCE(v_group.group_name, 'بدون جروب'),
        'department_name', v_group.department_name,
        'supervisor_doctor_name', v_group.supervisor_doctor_name,
        'student_classification', v_profile.student_classification,
        'previous_work_experience', COALESCE(v_profile.previous_work_experience, false),
        'previous_workplace', v_profile.previous_workplace,
        'previous_work_department', v_profile.previous_work_department,
        'previous_work_experience_details', v_profile.previous_work_experience_details,
        'registration_status', v_profile.registration_status,
        'is_approved', v_profile.is_approved,
        'avatar_url', v_profile.avatar_url,
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

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.get_admin_students_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_student_full_profile(UUID) TO authenticated;
