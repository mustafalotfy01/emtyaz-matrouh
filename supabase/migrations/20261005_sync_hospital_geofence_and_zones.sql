-- ==============================================================================
-- MIGRATION: Synchronize Hospital Geofence with App Settings & Attendance Zones
-- Date: 2026-10-05
-- File: 20261005_sync_hospital_geofence_and_zones.sql
-- ==============================================================================

-- 1. Ensure public.app_settings table exists
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Setup & Harden RLS for app_settings
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all users to read app settings" ON public.app_settings;
CREATE POLICY "Allow all users to read app settings"
  ON public.app_settings
  FOR SELECT
  TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS "Allow super_admin to manage app settings" ON public.app_settings;
DROP POLICY IF EXISTS "Allow staff to manage app settings" ON public.app_settings;
CREATE POLICY "Allow staff to manage app settings"
  ON public.app_settings
  FOR ALL
  TO authenticated, service_role
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('super_admin', 'leader')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('super_admin', 'leader')
    )
  );

-- 3. Ensure public.attendance_zones permissions permit super_admin & leader
ALTER TABLE public.attendance_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_zones_select" ON public.attendance_zones;
CREATE POLICY "attendance_zones_select" ON public.attendance_zones
    FOR SELECT
    TO authenticated, service_role
    USING (true);

DROP POLICY IF EXISTS "attendance_zones_manage" ON public.attendance_zones;
CREATE POLICY "attendance_zones_manage" ON public.attendance_zones
    FOR ALL
    TO authenticated, service_role
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role IN ('super_admin', 'leader')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role IN ('super_admin', 'leader')
        )
    );

-- 4. Backward compatibility view for legacy system_settings
CREATE OR REPLACE VIEW public.system_settings AS
  SELECT key AS setting_key, value AS setting_value, updated_at FROM public.app_settings;

-- 5. Seed default hospital geofence if absent
INSERT INTO public.app_settings (key, value, updated_at)
VALUES (
    'hospital_geofence',
    jsonb_build_object(
        'hospital_name', 'مستشفى مطروح العام',
        'latitude', 31.3543,
        'longitude', 27.2373,
        'radius_meters', 250.0,
        'address', 'شارع الجلاء، مرسى مطروح',
        'updated_at', NOW()
    ),
    NOW()
)
ON CONFLICT (key) DO NOTHING;

-- 6. Update record_attendance_check_in RPC to respect dynamic app_settings & attendance_zones
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
    v_target_lat DOUBLE PRECISION;
    v_target_lon DOUBLE PRECISION;
    v_target_radius DOUBLE PRECISION;
    v_hospital_name TEXT;
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
    SELECT id, check_in_time INTO v_active_record
    FROM public.attendance
    WHERE student_id = v_caller_id
      AND check_out_time IS NULL
    ORDER BY check_in_time DESC
    LIMIT 1;

    IF v_active_record.id IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate check-in: An active attendance shift already exists for this student.';
    END IF;

    -- 5. Retrieve Authoritative Hospital Geofence Zone
    -- 5.a Check dynamic hospital geofence in app_settings first
    SELECT 
        (value->>'latitude')::DOUBLE PRECISION,
        (value->>'longitude')::DOUBLE PRECISION,
        (value->>'radius_meters')::DOUBLE PRECISION,
        COALESCE(value->>'hospital_name', 'مستشفى مطروح العام')
    INTO v_target_lat, v_target_lon, v_target_radius, v_hospital_name
    FROM public.app_settings
    WHERE key = 'hospital_geofence'
    LIMIT 1;

    -- 5.b If not found in app_settings or null coordinates, fallback to attendance_zones
    IF v_target_lat IS NULL OR v_target_lon IS NULL THEN
        IF p_department_id IS NOT NULL THEN
            SELECT id, hospital_name, latitude, longitude, radius_meters, department_id
            INTO v_zone
            FROM public.attendance_zones
            WHERE department_id = p_department_id AND is_active = true
            LIMIT 1;
        END IF;

        IF v_zone.id IS NULL THEN
            SELECT id, hospital_name, latitude, longitude, radius_meters, department_id
            INTO v_zone
            FROM public.attendance_zones
            WHERE is_active = true
            ORDER BY created_at ASC
            LIMIT 1;
        END IF;

        IF v_zone.id IS NOT NULL THEN
            v_target_lat := v_zone.latitude;
            v_target_lon := v_zone.longitude;
            v_target_radius := v_zone.radius_meters;
            v_hospital_name := v_zone.hospital_name;
        END IF;
    END IF;

    -- 5.c Ultimate fallback default coordinates
    IF v_target_lat IS NULL OR v_target_lon IS NULL THEN
        v_target_lat := 31.3543;
        v_target_lon := 27.2373;
        v_target_radius := 250.0;
        v_hospital_name := 'مستشفى مطروح العام';
    END IF;

    -- 6. Server-Side Distance Calculation
    v_distance := public.calculate_haversine_distance(
        p_latitude,
        p_longitude,
        v_target_lat,
        v_target_lon
    );

    -- 7. Authoritative Geofence Decision
    v_is_inside := (v_distance <= v_target_radius);

    IF NOT v_is_inside THEN
        RAISE EXCEPTION 'Geofence violation: Device location (distance: %m) is outside the permitted hospital zone (radius: %m).',
            ROUND(v_distance::NUMERIC, 1),
            ROUND(v_target_radius::NUMERIC, 1);
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

-- 7. Authoritative Hospital Geofence Update RPC for Staff (super_admin & leader)
CREATE OR REPLACE FUNCTION public.update_hospital_geofence(
    p_hospital_name TEXT,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION,
    p_address TEXT DEFAULT 'مرسى مطروح'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_role user_role;
    v_config JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required: Anonymous callers cannot update hospital geofence.';
    END IF;

    SELECT role INTO v_role FROM public.profiles WHERE id = v_caller_id;
    IF v_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Only super_admin or leader can update hospital geofence.';
    END IF;

    v_config := jsonb_build_object(
        'hospital_name', COALESCE(NULLIF(TRIM(p_hospital_name), ''), 'مستشفى مطروح العام'),
        'latitude', p_latitude,
        'longitude', p_longitude,
        'radius_meters', p_radius_meters,
        'address', COALESCE(NULLIF(TRIM(p_address), ''), 'مرسى مطروح'),
        'updated_at', NOW()
    );

    -- Update or insert app_settings
    INSERT INTO public.app_settings (key, value, updated_at)
    VALUES ('hospital_geofence', v_config, NOW())
    ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value, updated_at = NOW();

    -- Update active zone in attendance_zones
    UPDATE public.attendance_zones
    SET hospital_name = COALESCE(NULLIF(TRIM(p_hospital_name), ''), 'مستشفى مطروح العام'),
        latitude = p_latitude,
        longitude = p_longitude,
        radius_meters = p_radius_meters
    WHERE is_active = true;

    -- If no active zone exists in attendance_zones, insert one
    IF NOT FOUND THEN
        INSERT INTO public.attendance_zones (hospital_name, latitude, longitude, radius_meters, is_active)
        VALUES (COALESCE(NULLIF(TRIM(p_hospital_name), ''), 'مستشفى مطروح العام'), p_latitude, p_longitude, p_radius_meters, true);
    END IF;

    RETURN jsonb_build_object('success', true, 'config', v_config);
END;
$$;

-- 8. Secure execution grants
REVOKE ALL ON FUNCTION public.record_attendance_check_in(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_attendance_check_in(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.record_attendance_check_in(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.update_hospital_geofence(TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_hospital_geofence(TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_hospital_geofence(TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO authenticated, service_role;
