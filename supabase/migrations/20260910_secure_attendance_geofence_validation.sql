-- ==============================================================================
-- MIGRATION: Nurse Matrouh Attendance Geofence & Location Validation Hardening
-- Date: 2026-09-10
-- File: 20260910_secure_attendance_geofence_validation.sql
-- Description:
--   Item 8: Client-reported GPS coordinates accepted without sufficient server-side validation.
--
-- Security Controls Enforced:
--   1. Secure public.attendance_zones:
--      - Enable RLS
--      - SELECT: accessible to authenticated and service_role
--      - INSERT / UPDATE / DELETE: restricted strictly to super_admin and leader
--      - Explicitly REVOKE ALL on attendance_zones FROM anon
--
--   2. Restrict Direct INSERT & UPDATE on public.attendance:
--      - Students can no longer directly INSERT or UPDATE rows in public.attendance.
--      - Direct writes reserved exclusively for staff (super_admin, leader) for administrative overrides.
--
--   3. Server-Side Geofence & Check-In RPC: record_attendance_check_in()
--      - Student identity bound exclusively to auth.uid()
--      - Client-supplied coordinates validated: latitude [-90, 90], longitude [-180, 180], non-null, finite
--      - Target geofence and radius retrieved strictly from public.attendance_zones
--      - Distance computed on the server using authoritative Haversine formula
--      - Server-side decision: checks if distance <= allowed radius
--      - Timestamp bound strictly to PostgreSQL NOW()
--      - Duplicate check-in prevention for active shifts
--      - REVOKE EXECUTE FROM anon
--
--   4. Server-Side Check-Out RPC: record_attendance_check_out()
--      - Student identity bound exclusively to auth.uid()
--      - Coordinates validated
--      - Check-out timestamp bound strictly to PostgreSQL NOW()
--      - REVOKE EXECUTE FROM anon
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. HARDEN PUBLIC.ATTENDANCE_ZONES RLS & PRIVILEGES
-- ------------------------------------------------------------------------------
ALTER TABLE public.attendance_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public attendance_zones read" ON public.attendance_zones;
DROP POLICY IF EXISTS "attendance_zones_select" ON public.attendance_zones;
DROP POLICY IF EXISTS "attendance_zones_manage" ON public.attendance_zones;

-- Authenticated users (students & staff) can read active zones
CREATE POLICY "attendance_zones_select" ON public.attendance_zones
    FOR SELECT
    TO authenticated, service_role
    USING (is_active = true OR public.get_auth_role() IN ('super_admin', 'leader'));

-- Only super_admin and leader can insert, update, or delete zones
CREATE POLICY "attendance_zones_manage" ON public.attendance_zones
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

-- Block anonymous access
REVOKE ALL ON public.attendance_zones FROM anon;
GRANT SELECT ON public.attendance_zones TO authenticated;


-- ------------------------------------------------------------------------------
-- 2. HARDEN PUBLIC.ATTENDANCE TABLE RLS & PRIVILEGES
-- ------------------------------------------------------------------------------
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_select" ON public.attendance;
DROP POLICY IF EXISTS "attendance_insert" ON public.attendance;
DROP POLICY IF EXISTS "attendance_update" ON public.attendance;
DROP POLICY IF EXISTS "attendance_delete" ON public.attendance;

-- SELECT: Students view their own attendance, staff view all
CREATE POLICY "attendance_select" ON public.attendance
    FOR SELECT
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

-- INSERT: Only administrative staff can directly insert (students MUST use the secure RPC)
CREATE POLICY "attendance_insert" ON public.attendance
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

-- UPDATE: Only administrative staff can directly update (students checkout via the secure RPC)
CREATE POLICY "attendance_update" ON public.attendance
    FOR UPDATE
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

-- DELETE: Super admin only
CREATE POLICY "attendance_delete" ON public.attendance
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() = 'super_admin'
    );

REVOKE ALL ON public.attendance FROM anon;
GRANT SELECT ON public.attendance TO authenticated;


-- ------------------------------------------------------------------------------
-- 3. HAVERSINE DISTANCE FUNCTION (SERVER-SIDE)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_haversine_distance(
    p_lat1 DOUBLE PRECISION,
    p_lon1 DOUBLE PRECISION,
    p_lat2 DOUBLE PRECISION,
    p_lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_r DOUBLE PRECISION := 6371000.0; -- Earth radius in meters
    v_dlat DOUBLE PRECISION;
    v_dlon DOUBLE PRECISION;
    v_a DOUBLE PRECISION;
    v_c DOUBLE PRECISION;
BEGIN
    v_dlat := radians(p_lat2 - p_lat1);
    v_dlon := radians(p_lon2 - p_lon1);

    v_a := sin(v_dlat / 2.0) * sin(v_dlat / 2.0) +
           cos(radians(p_lat1)) * cos(radians(p_lat2)) *
           sin(v_dlon / 2.0) * sin(v_dlon / 2.0);

    -- Clamp v_a to [0, 1] against rounding errors
    IF v_a < 0.0 THEN v_a := 0.0; END IF;
    IF v_a > 1.0 THEN v_a := 1.0; END IF;

    v_c := 2.0 * atan2(sqrt(v_a), sqrt(1.0 - v_a));
    RETURN v_r * v_c;
END;
$$;


-- ------------------------------------------------------------------------------
-- 4. SECURE CHECK-IN RPC: record_attendance_check_in
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_attendance_check_in(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_gps_accuracy DOUBLE PRECISION DEFAULT NULL,
    p_biometric_method TEXT DEFAULT 'web_session',
    p_department_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role user_role;
    v_zone RECORD;
    v_distance DOUBLE PRECISION;
    v_is_inside BOOLEAN;
    v_active_record RECORD;
    v_new_record RECORD;
    v_dept_name TEXT;
    v_user_full_name TEXT;
BEGIN
    -- 1. Authentication Check
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required: Anonymous callers cannot record attendance.';
    END IF;

    -- 2. Verify Caller Profile
    SELECT role, full_name INTO v_caller_role, v_user_full_name
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User profile not found.';
    END IF;

    -- 3. Coordinate Range Validation
    IF p_latitude IS NULL OR p_longitude IS NULL THEN
        RAISE EXCEPTION 'Invalid coordinates: Latitude and longitude are required.';
    END IF;

    IF p_latitude < -90.0 OR p_latitude > 90.0 THEN
        RAISE EXCEPTION 'Invalid latitude: Must be between -90 and 90 degrees.';
    END IF;

    IF p_longitude < -180.0 OR p_longitude > 180.0 THEN
        RAISE EXCEPTION 'Invalid longitude: Must be between -180 and 180 degrees.';
    END IF;

    -- 4. Duplicate Check-In Guard
    -- Prevent multiple unclosed check-ins for the same student
    SELECT id, check_in_time INTO v_active_record
    FROM public.attendance
    WHERE student_id = v_caller_id
      AND check_out_time IS NULL
    ORDER BY check_in_time DESC
    LIMIT 1;

    IF v_active_record.id IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate check-in: An active attendance shift already exists for this student.';
    END IF;

    -- 5. Retrieve Authoritative Geofence Zone
    IF p_department_id IS NOT NULL THEN
        SELECT id, hospital_name, latitude, longitude, radius_meters, department_id
        INTO v_zone
        FROM public.attendance_zones
        WHERE department_id = p_department_id AND is_active = true
        LIMIT 1;
    END IF;

    -- If no department-specific zone found, fallback to active default hospital zone
    IF v_zone.id IS NULL THEN
        SELECT id, hospital_name, latitude, longitude, radius_meters, department_id
        INTO v_zone
        FROM public.attendance_zones
        WHERE is_active = true
        ORDER BY created_at ASC
        LIMIT 1;
    END IF;

    IF v_zone.id IS NULL THEN
        RAISE EXCEPTION 'Configuration error: No active attendance geofence zone found.';
    END IF;

    -- 6. Server-Side Distance Calculation
    v_distance := public.calculate_haversine_distance(
        p_latitude,
        p_longitude,
        v_zone.latitude,
        v_zone.longitude
    );

    -- 7. Authoritative Geofence Decision
    v_is_inside := (v_distance <= v_zone.radius_meters);

    IF NOT v_is_inside THEN
        RAISE EXCEPTION 'Geofence violation: Device location (distance: %m) is outside the permitted hospital zone (radius: %m).',
            ROUND(v_distance::NUMERIC, 1),
            ROUND(v_zone.radius_meters::NUMERIC, 1);
    END IF;

    -- Resolve Department Name for display
    SELECT name_ar INTO v_dept_name
    FROM public.departments
    WHERE id = COALESCE(p_department_id, v_zone.department_id);

    -- 8. Authoritative Server Insertion
    INSERT INTO public.attendance (
        student_id,
        department_id,
        check_in_time,
        check_in_latitude,
        check_in_longitude,
        geofence_status,
        biometric_verified,
        status,
        late_minutes,
        created_at
    ) VALUES (
        v_caller_id,
        COALESCE(p_department_id, v_zone.department_id),
        NOW(),
        p_latitude,
        p_longitude,
        true,
        true,
        'present',
        0,
        NOW()
    )
    RETURNING * INTO v_new_record;

    -- 9. Return Sanitized Record
    RETURN jsonb_build_object(
        'id', v_new_record.id,
        'student_id', v_new_record.student_id,
        'student_name', v_user_full_name,
        'department_name', COALESCE(v_dept_name, 'قسم الطوارئ والعناية'),
        'check_in_time', v_new_record.check_in_time,
        'check_out_time', v_new_record.check_out_time,
        'check_in_latitude', v_new_record.check_in_latitude,
        'check_in_longitude', v_new_record.check_in_longitude,
        'gps_accuracy', p_gps_accuracy,
        'geofence_distance', ROUND(v_distance::NUMERIC, 1),
        'geofence_status', true,
        'biometric_verified', true,
        'biometric_method', COALESCE(p_biometric_method, 'fingerprint'),
        'status', v_new_record.status,
        'late_minutes', v_new_record.late_minutes
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 5. SECURE CHECK-OUT RPC: record_attendance_check_out
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_attendance_check_out(
    p_attendance_id UUID DEFAULT NULL,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_target_id UUID;
    v_updated_record RECORD;
    v_dept_name TEXT;
    v_user_full_name TEXT;
BEGIN
    -- 1. Authentication Check
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required: Anonymous callers cannot check out.';
    END IF;

    -- 2. Coordinate Range Validation (if supplied)
    IF p_latitude IS NOT NULL AND (p_latitude < -90.0 OR p_latitude > 90.0) THEN
        RAISE EXCEPTION 'Invalid latitude: Must be between -90 and 90 degrees.';
    END IF;

    IF p_longitude IS NOT NULL AND (p_longitude < -180.0 OR p_longitude > 180.0) THEN
        RAISE EXCEPTION 'Invalid longitude: Must be between -180 and 180 degrees.';
    END IF;

    -- 3. Resolve Target Attendance Record
    IF p_attendance_id IS NOT NULL THEN
        SELECT id INTO v_target_id
        FROM public.attendance
        WHERE id = p_attendance_id
          AND student_id = v_caller_id
          AND check_out_time IS NULL;
    ELSE
        SELECT id INTO v_target_id
        FROM public.attendance
        WHERE student_id = v_caller_id
          AND check_out_time IS NULL
        ORDER BY check_in_time DESC
        LIMIT 1;
    END IF;

    IF v_target_id IS NULL THEN
        RAISE EXCEPTION 'No active check-in record found for this student to check out.';
    END IF;

    -- 4. Server-Side Check-Out Timestamp & Location Update
    UPDATE public.attendance
    SET check_out_time = NOW(),
        check_out_latitude = p_latitude,
        check_out_longitude = p_longitude
    WHERE id = v_target_id
    RETURNING * INTO v_updated_record;

    -- Get student name & dept name
    SELECT full_name INTO v_user_full_name FROM public.profiles WHERE id = v_caller_id;
    SELECT name_ar INTO v_dept_name FROM public.departments WHERE id = v_updated_record.department_id;

    RETURN jsonb_build_object(
        'id', v_updated_record.id,
        'student_id', v_updated_record.student_id,
        'student_name', v_user_full_name,
        'department_name', COALESCE(v_dept_name, 'قسم الطوارئ والعناية'),
        'check_in_time', v_updated_record.check_in_time,
        'check_out_time', v_updated_record.check_out_time,
        'check_in_latitude', v_updated_record.check_in_latitude,
        'check_in_longitude', v_updated_record.check_in_longitude,
        'check_out_latitude', v_updated_record.check_out_latitude,
        'check_out_longitude', v_updated_record.check_out_longitude,
        'geofence_status', v_updated_record.geofence_status,
        'biometric_verified', v_updated_record.biometric_verified,
        'status', v_updated_record.status,
        'late_minutes', v_updated_record.late_minutes
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 6. PERMISSION HARDENING FOR ATTENDANCE RPCS
-- ------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.record_attendance_check_in(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_attendance_check_in(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.record_attendance_check_in(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.record_attendance_check_out(UUID, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_attendance_check_out(UUID, DOUBLE PRECISION, DOUBLE PRECISION) FROM anon;
GRANT EXECUTE ON FUNCTION public.record_attendance_check_out(UUID, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.calculate_haversine_distance(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.calculate_haversine_distance(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM anon;
GRANT EXECUTE ON FUNCTION public.calculate_haversine_distance(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;
