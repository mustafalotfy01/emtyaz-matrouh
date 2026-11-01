-- ==============================================================================
-- MIGRATION: Leader & Doctor Clinical Training Management System
-- Date: 2026-10-31
-- File: 20261031_clinical_training_management.sql
-- Description:
--   1. Clinical Exceptions (عارضة - Late Arrival / Absence Exception):
--      - Long shift -> Late arrival at 2:00 PM (14:00)
--      - Morning shift -> Absent for that shift
--      - Retains original attendance status without destruction.
--   2. Clinical Permissions (ترك عمل - Early Leave Permission):
--      - Student leaves early with logged departure time and optional reason.
--      - Preserves morning attendance; shows attended then granted leave.
--   3. Clinical Compensations (التعويضات):
--      - Tracks due, completed, and cancelled compensations with original absence link.
--   4. Attendance Hardening & Morning Pass Batch RPC:
--      - Adds recorded_by and notes to attendance.
--      - record_morning_attendance_batch() for fast, single-transaction 8:30 AM pass.
--      - Server-side Cairo time validation and duplicate prevention.
--   5. Strict Horizontal & Vertical RLS Policies:
--      - Students can only view their own data.
--      - Evaluating doctors can view and manage their assigned groups.
--      - Leaders & Super Admins have full supervision access.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ATTENDANCE EXTENSIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.attendance
    ADD COLUMN IF NOT EXISTS recorded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS notes TEXT;

CREATE INDEX IF NOT EXISTS idx_attendance_recorded_by ON public.attendance(recorded_by);
CREATE INDEX IF NOT EXISTS idx_attendance_student_checkin ON public.attendance(student_id, check_in_time);

-- ------------------------------------------------------------------------------
-- 2. CLINICAL EXCEPTIONS (عارضة)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clinical_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.student_groups(id) ON DELETE SET NULL,
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    exception_date DATE NOT NULL,
    shift_type shift_type NOT NULL,
    impact TEXT NOT NULL, -- e.g. 'long_shift_late_arrival_2pm' or 'morning_shift_absent'
    impact_description_ar TEXT NOT NULL,
    note TEXT,
    recorded_by UUID NOT NULL REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_student_date_clinical_exception UNIQUE (student_id, exception_date)
);

CREATE INDEX IF NOT EXISTS idx_clinical_exceptions_student_date ON public.clinical_exceptions(student_id, exception_date);
CREATE INDEX IF NOT EXISTS idx_clinical_exceptions_group ON public.clinical_exceptions(group_id);
CREATE INDEX IF NOT EXISTS idx_clinical_exceptions_date ON public.clinical_exceptions(exception_date);

-- ------------------------------------------------------------------------------
-- 3. CLINICAL PERMISSIONS (ترك عمل)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clinical_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.student_groups(id) ON DELETE SET NULL,
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    permission_date DATE NOT NULL,
    leave_time TIME NOT NULL,
    shift_type shift_type,
    reason TEXT,
    granted_by UUID NOT NULL REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_student_date_clinical_permission UNIQUE (student_id, permission_date)
);

CREATE INDEX IF NOT EXISTS idx_clinical_permissions_student_date ON public.clinical_permissions(student_id, permission_date);
CREATE INDEX IF NOT EXISTS idx_clinical_permissions_group ON public.clinical_permissions(group_id);
CREATE INDEX IF NOT EXISTS idx_clinical_permissions_date ON public.clinical_permissions(permission_date);

-- ------------------------------------------------------------------------------
-- 4. CLINICAL COMPENSATIONS (التعويضات)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clinical_compensations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.student_groups(id) ON DELETE SET NULL,
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    original_date DATE,
    compensation_date DATE NOT NULL,
    shift_type shift_type NOT NULL,
    reason TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'due' CHECK (status IN ('due', 'completed', 'cancelled')),
    recorded_by UUID NOT NULL REFERENCES public.profiles(id),
    executed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clinical_compensations_student ON public.clinical_compensations(student_id);
CREATE INDEX IF NOT EXISTS idx_clinical_compensations_group ON public.clinical_compensations(group_id);
CREATE INDEX IF NOT EXISTS idx_clinical_compensations_comp_date ON public.clinical_compensations(compensation_date);
CREATE INDEX IF NOT EXISTS idx_clinical_compensations_status ON public.clinical_compensations(status);

-- ------------------------------------------------------------------------------
-- 5. ENABLE ROW LEVEL SECURITY
-- ------------------------------------------------------------------------------
ALTER TABLE public.clinical_exceptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinical_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinical_compensations ENABLE ROW LEVEL SECURITY;

-- 5.1 RLS: clinical_exceptions
DROP POLICY IF EXISTS "clinical_exceptions_select" ON public.clinical_exceptions;
CREATE POLICY "clinical_exceptions_select" ON public.clinical_exceptions
    FOR SELECT TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_exceptions_insert_staff" ON public.clinical_exceptions;
CREATE POLICY "clinical_exceptions_insert_staff" ON public.clinical_exceptions
    FOR INSERT TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_exceptions_update_staff" ON public.clinical_exceptions;
CREATE POLICY "clinical_exceptions_update_staff" ON public.clinical_exceptions
    FOR UPDATE TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_exceptions_delete_staff" ON public.clinical_exceptions;
CREATE POLICY "clinical_exceptions_delete_staff" ON public.clinical_exceptions
    FOR DELETE TO authenticated, service_role
    USING (public.get_auth_role() IN ('super_admin', 'leader'));

-- 5.2 RLS: clinical_permissions
DROP POLICY IF EXISTS "clinical_permissions_select" ON public.clinical_permissions;
CREATE POLICY "clinical_permissions_select" ON public.clinical_permissions
    FOR SELECT TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_permissions_insert_staff" ON public.clinical_permissions;
CREATE POLICY "clinical_permissions_insert_staff" ON public.clinical_permissions
    FOR INSERT TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_permissions_update_staff" ON public.clinical_permissions;
CREATE POLICY "clinical_permissions_update_staff" ON public.clinical_permissions
    FOR UPDATE TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_permissions_delete_staff" ON public.clinical_permissions;
CREATE POLICY "clinical_permissions_delete_staff" ON public.clinical_permissions
    FOR DELETE TO authenticated, service_role
    USING (public.get_auth_role() IN ('super_admin', 'leader'));

-- 5.3 RLS: clinical_compensations
DROP POLICY IF EXISTS "clinical_compensations_select" ON public.clinical_compensations;
CREATE POLICY "clinical_compensations_select" ON public.clinical_compensations
    FOR SELECT TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_compensations_insert_staff" ON public.clinical_compensations;
CREATE POLICY "clinical_compensations_insert_staff" ON public.clinical_compensations
    FOR INSERT TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_compensations_update_staff" ON public.clinical_compensations;
CREATE POLICY "clinical_compensations_update_staff" ON public.clinical_compensations
    FOR UPDATE TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR (
            public.get_auth_role() = 'evaluating_doctor'
            AND (
                group_id IN (SELECT id FROM public.student_groups WHERE supervisor_doctor_id = auth.uid())
                OR department_id IN (SELECT department_id FROM public.department_supervisors WHERE doctor_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "clinical_compensations_delete_staff" ON public.clinical_compensations;
CREATE POLICY "clinical_compensations_delete_staff" ON public.clinical_compensations
    FOR DELETE TO authenticated, service_role
    USING (public.get_auth_role() IN ('super_admin', 'leader'));


-- ------------------------------------------------------------------------------
-- 6. RPC: record_morning_attendance_batch
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_morning_attendance_batch(
    p_records JSONB,
    p_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role user_role;
    v_target_date DATE;
    v_item JSONB;
    v_student_id UUID;
    v_status attendance_status;
    v_department_id UUID;
    v_notes TEXT;
    v_existing_id UUID;
    v_saved_count INT := 0;
    v_cairo_time TIMESTAMPTZ := NOW() AT TIME ZONE 'Africa/Cairo';
BEGIN
    -- 1. Authentication & Permission Verification
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User is not authenticated.';
    END IF;

    v_caller_role := public.get_auth_role();
    IF v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Permission denied: Only Leaders and Super Admins can record morning batch attendance.';
    END IF;

    -- Determine authoritative date (Africa/Cairo)
    v_target_date := COALESCE(p_date, (v_cairo_time)::DATE);

    -- Loop through JSON array items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_records)
    LOOP
        v_student_id := (v_item->>'student_id')::UUID;
        v_status := (v_item->>'status')::attendance_status;
        v_department_id := NULLIF(v_item->>'department_id', '')::UUID;
        v_notes := v_item->>'notes';

        IF v_student_id IS NULL OR v_status IS NULL THEN
            CONTINUE;
        END IF;

        -- Fallback department if null: get from student group monthly assignment or profile
        IF v_department_id IS NULL THEN
            SELECT gmd.department_id INTO v_department_id
            FROM public.profiles p
            JOIN public.group_monthly_departments gmd 
              ON gmd.group_id = p.student_group_id
             AND gmd.year = EXTRACT(YEAR FROM v_target_date)::INT
             AND gmd.month = EXTRACT(MONTH FROM v_target_date)::INT
            WHERE p.id = v_student_id
            LIMIT 1;

            IF v_department_id IS NULL THEN
                -- Try static department on group
                SELECT sg.department_id INTO v_department_id
                FROM public.profiles p
                JOIN public.student_groups sg ON sg.id = p.student_group_id
                WHERE p.id = v_student_id
                LIMIT 1;
            END IF;

            -- Final fallback to first active department
            IF v_department_id IS NULL THEN
                SELECT id INTO v_department_id FROM public.departments WHERE is_active = true LIMIT 1;
            END IF;
        END IF;

        -- Check existing attendance record for today (in Cairo date)
        SELECT id INTO v_existing_id
        FROM public.attendance
        WHERE student_id = v_student_id
          AND ((check_in_time AT TIME ZONE 'Africa/Cairo')::DATE = v_target_date)
        ORDER BY check_in_time DESC
        LIMIT 1;

        IF v_existing_id IS NOT NULL THEN
            -- Update existing record to avoid duplicate morning rows
            UPDATE public.attendance
            SET status = v_status,
                department_id = COALESCE(v_department_id, department_id),
                recorded_by = auth.uid(),
                notes = COALESCE(v_notes, notes)
            WHERE id = v_existing_id;
        ELSE
            -- Insert new attendance record
            INSERT INTO public.attendance (
                student_id,
                department_id,
                check_in_time,
                geofence_status,
                biometric_verified,
                status,
                late_minutes,
                recorded_by,
                notes,
                created_at
            ) VALUES (
                v_student_id,
                v_department_id,
                NOW(),
                true,
                false,
                v_status,
                0,
                auth.uid(),
                v_notes,
                NOW()
            );
        END IF;

        v_saved_count := v_saved_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'saved_count', v_saved_count,
        'date', v_target_date,
        'server_timestamp', NOW()
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 7. RPC: record_clinical_exception (عارضة)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_clinical_exception(
    p_student_id UUID,
    p_date DATE,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role user_role;
    v_student_group_id UUID;
    v_group_doctor_id UUID;
    v_entry RECORD;
    v_shift_type shift_type;
    v_department_id UUID;
    v_impact TEXT;
    v_impact_ar TEXT;
    v_existing_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User is not authenticated.';
    END IF;

    v_caller_role := public.get_auth_role();

    -- Get student group & assigned doctor
    SELECT p.student_group_id, sg.supervisor_doctor_id
    INTO v_student_group_id, v_group_doctor_id
    FROM public.profiles p
    LEFT JOIN public.student_groups sg ON sg.id = p.student_group_id
    WHERE p.id = p_student_id;

    -- Verify caller authorization
    IF v_caller_role NOT IN ('super_admin', 'leader') THEN
        IF v_caller_role = 'evaluating_doctor' THEN
            IF v_group_doctor_id IS NULL OR v_group_doctor_id != auth.uid() THEN
                RAISE EXCEPTION 'Permission denied: Doctors can only add exceptions for students in their assigned groups.';
            END IF;
        ELSE
            RAISE EXCEPTION 'Permission denied: Unauthorized role.';
        END IF;
    END IF;

    -- Check if student has an approved/published shift on this date in roster_entries
    SELECT re.shift_type, re.department_id
    INTO v_shift_type, v_department_id
    FROM public.roster_entries re
    WHERE re.student_id = p_student_id
      AND re.shift_date = p_date
      AND re.status IN ('approved', 'published')
    LIMIT 1;

    IF v_shift_type IS NULL THEN
        -- Check shift without strict approved status as fallback
        SELECT re.shift_type, re.department_id
        INTO v_shift_type, v_department_id
        FROM public.roster_entries re
        WHERE re.student_id = p_student_id
          AND re.shift_date = p_date
        LIMIT 1;
    END IF;

    IF v_shift_type IS NULL THEN
        RAISE EXCEPTION 'لا يمكن إضافة عارضة للطالب لعدم وجود شيفت مجدول في هذا اليوم (%s).', p_date;
    END IF;

    -- Compute clinical impact strictly according to rules:
    -- If Long shift -> arrives at 2:00 PM (14:00)
    -- If Morning shift -> absent for this shift
    IF v_shift_type = 'long' THEN
        v_impact := 'long_shift_late_arrival_2pm';
        v_impact_ar := 'شيفت طويل (Long): حضور الساعة 02:00 ظهراً';
    ELSIF v_shift_type = 'morning' THEN
        v_impact := 'morning_shift_absent';
        v_impact_ar := 'شيفت صباحي: عدم حضور هذا الشيفت';
    ELSE
        v_impact := 'standard_exception';
        v_impact_ar := 'استثناء عارضة معتمد';
    END IF;

    -- Check duplicate exception on the same date
    SELECT id INTO v_existing_id
    FROM public.clinical_exceptions
    WHERE student_id = p_student_id
      AND exception_date = p_date;

    IF v_existing_id IS NOT NULL THEN
        RAISE EXCEPTION 'تم تسجيل عارضة مسبقاً لهذا الطالب في نفس اليوم (تاريخ: %s).', p_date;
    END IF;

    -- Insert clinical exception
    INSERT INTO public.clinical_exceptions (
        student_id,
        group_id,
        department_id,
        exception_date,
        shift_type,
        impact,
        impact_description_ar,
        note,
        recorded_by,
        created_at
    ) VALUES (
        p_student_id,
        v_student_group_id,
        v_department_id,
        p_date,
        v_shift_type,
        v_impact,
        v_impact_ar,
        p_note,
        auth.uid(),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'date', p_date,
        'shift_type', v_shift_type,
        'impact', v_impact,
        'impact_ar', v_impact_ar,
        'created_at', NOW()
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 8. RPC: record_clinical_permission (ترك عمل)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_clinical_permission(
    p_student_id UUID,
    p_date DATE,
    p_leave_time TIME,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role user_role;
    v_student_group_id UUID;
    v_group_doctor_id UUID;
    v_shift_type shift_type;
    v_department_id UUID;
    v_existing_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User is not authenticated.';
    END IF;

    v_caller_role := public.get_auth_role();

    SELECT p.student_group_id, sg.supervisor_doctor_id
    INTO v_student_group_id, v_group_doctor_id
    FROM public.profiles p
    LEFT JOIN public.student_groups sg ON sg.id = p.student_group_id
    WHERE p.id = p_student_id;

    IF v_caller_role NOT IN ('super_admin', 'leader') THEN
        IF v_caller_role = 'evaluating_doctor' THEN
            IF v_group_doctor_id IS NULL OR v_group_doctor_id != auth.uid() THEN
                RAISE EXCEPTION 'Permission denied: Doctors can only grant leave permissions for students in their assigned groups.';
            END IF;
        ELSE
            RAISE EXCEPTION 'Permission denied: Unauthorized role.';
        END IF;
    END IF;

    -- Lookup today's shift type if available
    SELECT re.shift_type, re.department_id
    INTO v_shift_type, v_department_id
    FROM public.roster_entries re
    WHERE re.student_id = p_student_id
      AND re.shift_date = p_date
    LIMIT 1;

    -- Check duplicate permission
    SELECT id INTO v_existing_id
    FROM public.clinical_permissions
    WHERE student_id = p_student_id
      AND permission_date = p_date;

    IF v_existing_id IS NOT NULL THEN
        UPDATE public.clinical_permissions
        SET leave_time = p_leave_time,
            reason = p_reason,
            granted_by = auth.uid(),
            updated_at = NOW()
        WHERE id = v_existing_id;
    ELSE
        INSERT INTO public.clinical_permissions (
            student_id,
            group_id,
            department_id,
            permission_date,
            leave_time,
            shift_type,
            reason,
            granted_by,
            created_at
        ) VALUES (
            p_student_id,
            v_student_group_id,
            v_department_id,
            p_date,
            p_leave_time,
            v_shift_type,
            p_reason,
            auth.uid(),
            NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'date', p_date,
        'leave_time', p_leave_time,
        'reason', p_reason,
        'granted_by', auth.uid()
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 9. RPC: record_clinical_compensation (إضافة تعويض)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_clinical_compensation(
    p_student_id UUID,
    p_compensation_date DATE,
    p_shift_type shift_type,
    p_original_date DATE DEFAULT NULL,
    p_reason TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role user_role;
    v_student_group_id UUID;
    v_group_doctor_id UUID;
    v_department_id UUID;
    v_comp_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User is not authenticated.';
    END IF;

    v_caller_role := public.get_auth_role();

    SELECT p.student_group_id, sg.supervisor_doctor_id
    INTO v_student_group_id, v_group_doctor_id
    FROM public.profiles p
    LEFT JOIN public.student_groups sg ON sg.id = p.student_group_id
    WHERE p.id = p_student_id;

    IF v_caller_role NOT IN ('super_admin', 'leader') THEN
        IF v_caller_role = 'evaluating_doctor' THEN
            IF v_group_doctor_id IS NULL OR v_group_doctor_id != auth.uid() THEN
                RAISE EXCEPTION 'Permission denied: Doctors can only add compensations for students in their assigned groups.';
            END IF;
        ELSE
            RAISE EXCEPTION 'Permission denied: Unauthorized role.';
        END IF;
    END IF;

    -- Lookup department
    SELECT gmd.department_id INTO v_department_id
    FROM public.group_monthly_departments gmd
    WHERE gmd.group_id = v_student_group_id
      AND gmd.year = EXTRACT(YEAR FROM p_compensation_date)::INT
      AND gmd.month = EXTRACT(MONTH FROM p_compensation_date)::INT
    LIMIT 1;

    INSERT INTO public.clinical_compensations (
        student_id,
        group_id,
        department_id,
        original_date,
        compensation_date,
        shift_type,
        reason,
        notes,
        status,
        recorded_by,
        created_at
    ) VALUES (
        p_student_id,
        v_student_group_id,
        v_department_id,
        p_original_date,
        p_compensation_date,
        p_shift_type,
        p_reason,
        p_notes,
        'due',
        auth.uid(),
        NOW()
    ) RETURNING id INTO v_comp_id;

    RETURN jsonb_build_object(
        'success', true,
        'compensation_id', v_comp_id,
        'student_id', p_student_id,
        'compensation_date', p_compensation_date,
        'status', 'due'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 10. RPC: update_compensation_status
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_compensation_status(
    p_compensation_id UUID,
    p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role user_role;
    v_comp RECORD;
    v_group_doctor_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Unauthorized.';
    END IF;

    IF p_status NOT IN ('due', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    SELECT * INTO v_comp FROM public.clinical_compensations WHERE id = p_compensation_id;
    IF v_comp.id IS NULL THEN
        RAISE EXCEPTION 'Compensation not found.';
    END IF;

    v_caller_role := public.get_auth_role();
    IF v_caller_role NOT IN ('super_admin', 'leader') THEN
        IF v_caller_role = 'evaluating_doctor' THEN
            SELECT supervisor_doctor_id INTO v_group_doctor_id 
            FROM public.student_groups WHERE id = v_comp.group_id;
            IF v_group_doctor_id != auth.uid() THEN
                RAISE EXCEPTION 'Permission denied.';
            END IF;
        ELSE
            RAISE EXCEPTION 'Permission denied.';
        END IF;
    END IF;

    UPDATE public.clinical_compensations
    SET status = p_status,
        executed_at = CASE WHEN p_status = 'completed' THEN NOW() ELSE NULL END,
        updated_at = NOW()
    WHERE id = p_compensation_id;

    RETURN jsonb_build_object(
        'success', true,
        'compensation_id', p_compensation_id,
        'status', p_status
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 11. GRANT RPC PERMISSIONS
-- ------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.record_morning_attendance_batch FROM anon;
REVOKE ALL ON FUNCTION public.record_clinical_exception FROM anon;
REVOKE ALL ON FUNCTION public.record_clinical_permission FROM anon;
REVOKE ALL ON FUNCTION public.record_clinical_compensation FROM anon;
REVOKE ALL ON FUNCTION public.update_compensation_status FROM anon;

GRANT EXECUTE ON FUNCTION public.record_morning_attendance_batch TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_clinical_exception TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_clinical_permission TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_clinical_compensation TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_compensation_status TO authenticated, service_role;
