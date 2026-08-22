-- ==============================================================================
-- MIGRATION: Nurse Matrouh Student Production Experience & Real Data Foundation
-- Date: 2026-08-21
-- File: 20260821_student_production_experience.sql
-- Description:
--   1. student_group_preferences table & RLS policies
--   2. community_posts extensions (is_featured) & community_comments table & RLS
--   3. case_handovers extensions (critical_notes, pending_tasks, doctor_score, doctor_comment, evaluated_by, evaluated_at, department_name, case_title)
--   4. get_student_leaderboard RPC (handles handover evaluation points & alphabetical sort for 0 pts)
--   5. validate_monthly_schedule_36h RPC (Saturday to Friday 36h rule for any full month)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. STUDENT GROUP PREFERENCES TABLE & RLS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_group_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    preferred_student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    priority INT NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_student_preferred_pair UNIQUE (student_id, preferred_student_id)
);

CREATE INDEX IF NOT EXISTS idx_group_pref_student ON public.student_group_preferences(student_id);
CREATE INDEX IF NOT EXISTS idx_group_pref_preferred ON public.student_group_preferences(preferred_student_id);

ALTER TABLE public.student_group_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "student_group_pref_select" ON public.student_group_preferences;
CREATE POLICY "student_group_pref_select" ON public.student_group_preferences
  FOR SELECT USING (
    student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "student_group_pref_insert" ON public.student_group_preferences;
CREATE POLICY "student_group_pref_insert" ON public.student_group_preferences
  FOR INSERT WITH CHECK (
    student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "student_group_pref_update" ON public.student_group_preferences;
CREATE POLICY "student_group_pref_update" ON public.student_group_preferences
  FOR UPDATE USING (
    student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "student_group_pref_delete" ON public.student_group_preferences;
CREATE POLICY "student_group_pref_delete" ON public.student_group_preferences
  FOR DELETE USING (
    student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

-- ------------------------------------------------------------------------------
-- 2. COMMUNITY POSTS EXTENSION & COMMENTS TABLE
-- ------------------------------------------------------------------------------
ALTER TABLE public.community_posts
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT false;

-- Allow students to create community posts
DROP POLICY IF EXISTS "community_posts_insert" ON public.community_posts;
CREATE POLICY "community_posts_insert" ON public.community_posts
  FOR INSERT WITH CHECK (
    auth.uid() = author_id
  );

CREATE TABLE IF NOT EXISTS public.community_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comm_comments_post ON public.community_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comm_comments_created ON public.community_comments(created_at ASC);

ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_comments_select" ON public.community_comments;
CREATE POLICY "community_comments_select" ON public.community_comments
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "community_comments_insert" ON public.community_comments;
CREATE POLICY "community_comments_insert" ON public.community_comments
  FOR INSERT WITH CHECK (
    auth.uid() = author_id
  );

DROP POLICY IF EXISTS "community_comments_delete" ON public.community_comments;
CREATE POLICY "community_comments_delete" ON public.community_comments
  FOR DELETE USING (
    auth.uid() = author_id
    OR public.get_auth_role() = 'super_admin'
  );

-- ------------------------------------------------------------------------------
-- 3. CASE HANDOVERS EXTENSIONS & DOCTOR EVALUATIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.case_handovers
  ADD COLUMN IF NOT EXISTS department_name TEXT,
  ADD COLUMN IF NOT EXISTS case_title TEXT,
  ADD COLUMN IF NOT EXISTS shift_name TEXT,
  ADD COLUMN IF NOT EXISTS critical_notes TEXT,
  ADD COLUMN IF NOT EXISTS pending_tasks TEXT,
  ADD COLUMN IF NOT EXISTS doctor_score DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS doctor_comment TEXT,
  ADD COLUMN IF NOT EXISTS evaluated_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS evaluated_at TIMESTAMPTZ;

-- Make sure RLS allows sender and receiver student, and staff
DROP POLICY IF EXISTS "case_handovers_select" ON public.case_handovers;
CREATE POLICY "case_handovers_select" ON public.case_handovers
  FOR SELECT USING (
    from_student_id = auth.uid()
    OR to_student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
  );

DROP POLICY IF EXISTS "case_handovers_insert" ON public.case_handovers;
CREATE POLICY "case_handovers_insert" ON public.case_handovers
  FOR INSERT WITH CHECK (
    from_student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "case_handovers_update" ON public.case_handovers;
CREATE POLICY "case_handovers_update" ON public.case_handovers
  FOR UPDATE USING (
    from_student_id = auth.uid()
    OR to_student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
  );

-- ------------------------------------------------------------------------------
-- 4. RPC: GET STUDENT LEADERBOARD (INTEGRATED EVALUATION & DETERMINISTIC SORT)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_student_leaderboard(
  p_requester_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_requester_role TEXT;
  v_is_staff BOOLEAN;
  v_leaderboard JSONB := '[]'::JSONB;
BEGIN
  -- Get requester role
  SELECT role::text INTO v_requester_role
  FROM public.profiles
  WHERE id = p_requester_id;

  v_is_staff := (v_requester_role IN ('super_admin', 'leader', 'evaluating_doctor'));

  -- Calculate score for all approved students
  WITH student_stats AS (
    SELECT
      p.id AS student_id,
      p.full_name,
      COALESCE(p.student_group, 'A') AS student_group,
      p.avatar_url,
      -- Attended Shifts
      COUNT(DISTINCT a.id) FILTER (WHERE a.status IN ('present', 'late', 'excused')) AS attended_shifts,
      -- Total attendance count for percentage
      COUNT(DISTINCT a.id) AS total_attendance_logs,
      -- Lates
      COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'late') AS late_count,
      -- Absences
      COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'absent') AS absent_count,
      -- Average Quiz Percentage
      COALESCE(AVG(qa.score_percentage), 0.0) AS avg_quiz_score,
      -- Approved Rewards Count
      COUNT(DISTINCT d.id) FILTER (WHERE d.action_type = 'reward' AND d.status = 'approved') AS approved_rewards,
      -- Approved Warnings Count
      COUNT(DISTINCT d.id) FILTER (WHERE d.action_type IN ('warning', 'final_warning') AND d.status = 'approved') AS approved_warnings,
      -- Approved Deductions Sum
      COALESCE(SUM(d.deduction_value) FILTER (WHERE d.status = 'approved' AND d.action_type IN ('deduction', 'official_violation')), 0.0) AS approved_deductions,
      -- Doctor-awarded handover points (ONLY valid evaluated handovers)
      COALESCE(SUM(h.doctor_score) FILTER (WHERE h.doctor_score IS NOT NULL AND h.evaluated_by IS NOT NULL), 0.0) AS handover_doctor_points
    FROM public.profiles p
    LEFT JOIN public.attendance a ON a.student_id = p.id
    LEFT JOIN public.quiz_attempts qa ON qa.student_id = p.id
    LEFT JOIN public.disciplinary_actions d ON d.student_id = p.id
    LEFT JOIN public.case_handovers h ON h.from_student_id = p.id
    WHERE p.role = 'student' AND (p.is_approved = true OR p.registration_status = 'approved')
    GROUP BY p.id, p.full_name, p.student_group, p.avatar_url
  ),
  scored_students AS (
    SELECT
      s.*,
      -- Attendance %
      CASE 
        WHEN s.total_attendance_logs > 0 THEN 
          ROUND(((s.attended_shifts::numeric / s.total_attendance_logs::numeric) * 100.0), 1)
        ELSE 100.0
      END AS attendance_percentage,
      -- Score Formula:
      -- clamp(100 + (2 * attended) + ((avg_quiz/100) * 15) + (5 * rewards) + handover_doctor_points - (2 * late) - (5 * absent) - (3 * warnings) - deductions, 0, 200)
      LEAST(200.0, GREATEST(0.0,
        100.0 
        + (2.0 * s.attended_shifts)
        + ((s.avg_quiz_score / 100.0) * 15.0)
        + (5.0 * s.approved_rewards)
        + s.handover_doctor_points
        - (2.0 * s.late_count)
        - (5.0 * s.absent_count)
        - (3.0 * s.approved_warnings)
        - s.approved_deductions
      )) AS calculated_score,
      ROW_NUMBER() OVER (
        ORDER BY 
          LEAST(200.0, GREATEST(0.0,
            100.0 
            + (2.0 * s.attended_shifts)
            + ((s.avg_quiz_score / 100.0) * 15.0)
            + (5.0 * s.approved_rewards)
            + s.handover_doctor_points
            - (2.0 * s.late_count)
            - (5.0 * s.absent_count)
            - (3.0 * s.approved_warnings)
            - s.approved_deductions
          )) DESC,
          s.attended_shifts DESC,
          s.full_name ASC
      ) AS rank
    FROM student_stats s
  )
  SELECT 
    CASE
      -- Staff receives full authorized breakdown
      WHEN v_is_staff THEN
        jsonb_agg(
          jsonb_build_object(
            'rank', rank,
            'student_id', student_id,
            'full_name', full_name,
            'student_group', student_group,
            'avatar_url', avatar_url,
            'score', ROUND(calculated_score::numeric, 1),
            'attended_shifts', attended_shifts,
            'attendance_percentage', attendance_percentage,
            'late_count', late_count,
            'absent_count', absent_count,
            'avg_quiz_score', ROUND(avg_quiz_score::numeric, 1),
            'approved_rewards', approved_rewards,
            'approved_warnings', approved_warnings,
            'approved_deductions', approved_deductions,
            'handover_doctor_points', handover_doctor_points
          )
        )
      -- Students receive privacy-filtered leaderboard
      ELSE
        jsonb_agg(
          jsonb_build_object(
            'rank', rank,
            'student_id', student_id,
            'full_name', full_name,
            'student_group', student_group,
            'avatar_url', avatar_url,
            'score', ROUND(calculated_score::numeric, 1),
            'attended_shifts', attended_shifts,
            'attendance_percentage', attendance_percentage
          )
        )
    END INTO v_leaderboard
  FROM scored_students;

  RETURN jsonb_build_object(
    'requester_role', COALESCE(v_requester_role, 'anonymous'),
    'is_staff', v_is_staff,
    'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb),
    'generated_at', NOW()
  );
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. RPC: VALIDATE MONTHLY SCHEDULE 36H RULE (SATURDAY TO FRIDAY WEEKS)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_monthly_schedule_36h(
  p_student_id UUID,
  p_roster_month_id TEXT,
  p_shifts JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_shift RECORD;
  v_week RECORD;
  v_weeks_result JSONB := '[]'::JSONB;
  v_is_valid BOOLEAN := true;
  v_error_msg TEXT := NULL;
BEGIN
  -- Temporary table for shifts in this validation call
  CREATE TEMP TABLE IF NOT EXISTS temp_submitted_shifts (
    shift_date DATE NOT NULL,
    shift_type TEXT NOT NULL,
    duration_hours INT NOT NULL
  ) ON COMMIT DROP;

  DELETE FROM temp_submitted_shifts;

  -- Parse JSON array
  FOR v_shift IN SELECT * FROM jsonb_to_recordset(p_shifts) AS x(shift_date DATE, shift_type TEXT) LOOP
    INSERT INTO temp_submitted_shifts (shift_date, shift_type, duration_hours)
    VALUES (
      v_shift.shift_date,
      v_shift.shift_type,
      CASE LOWER(v_shift.shift_type)
        WHEN 'morning' THEN 6
        WHEN 'long'    THEN 12
        WHEN 'night'   THEN 12
        ELSE 0
      END
    );
  END LOOP;

  -- Compute discrete Saturday-to-Friday week boundaries for all submitted dates
  FOR v_week IN (
    SELECT
      (shift_date - ((CAST(EXTRACT(DOW FROM shift_date) AS INT) + 1) % 7) * INTERVAL '1 day')::DATE AS week_start,
      ((shift_date - ((CAST(EXTRACT(DOW FROM shift_date) AS INT) + 1) % 7) * INTERVAL '1 day') + INTERVAL '6 days')::DATE AS week_end,
      SUM(duration_hours) AS total_hours
    FROM temp_submitted_shifts
    GROUP BY 1, 2
    ORDER BY 1
  ) LOOP
    v_weeks_result := v_weeks_result || jsonb_build_object(
      'week_start', v_week.week_start,
      'week_end', v_week.week_end,
      'total_hours', v_week.total_hours,
      'is_valid', (v_week.total_hours = 36)
    );

    IF v_week.total_hours != 36 THEN
      v_is_valid := false;
      IF v_error_msg IS NULL THEN
        v_error_msg := 'الأسبوع من ' || v_week.week_start || ' إلى ' || v_week.week_end || 
                       ' يحتوي على ' || v_week.total_hours || ' ساعة (المطلوب 36 ساعة بالضبط).';
      END IF;
    END IF;
  END LOOP;

  IF jsonb_array_length(v_weeks_result) = 0 THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'لم يتم تقديم أي شيفتات للتحقق منها',
      'weeks', '[]'::jsonb
    );
  END IF;

  RETURN jsonb_build_object(
    'valid', v_is_valid,
    'error', v_error_msg,
    'weeks', v_weeks_result,
    'total_weeks', jsonb_array_length(v_weeks_result)
  );
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. PERMISSIONS
-- ------------------------------------------------------------------------------
GRANT ALL ON public.student_group_preferences TO postgres, authenticated, service_role;
GRANT ALL ON public.community_comments TO postgres, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_monthly_schedule_36h(UUID, TEXT, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_student_leaderboard(UUID) TO authenticated, service_role;
