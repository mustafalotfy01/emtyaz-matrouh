-- ============================================================
-- MIGRATION: Leaderboard GPA / Points Sorting Mode & Privacy RPC
-- Date: 2026-08-23
-- ============================================================

-- 1. Ensure app_settings table exists
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Setup RLS for app_settings
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all users to read app settings" ON public.app_settings;
CREATE POLICY "Allow all users to read app settings"
  ON public.app_settings
  FOR SELECT
  TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS "Allow super_admin to manage app settings" ON public.app_settings;
CREATE POLICY "Allow super_admin to manage app settings"
  ON public.app_settings
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'super_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'super_admin'
    )
  );

-- Default sorting mode is GPA
INSERT INTO public.app_settings (key, value, updated_at)
VALUES ('leaderboard_sort_mode', '{"mode": "gpa"}'::jsonb, NOW())
ON CONFLICT (key) DO NOTHING;

-- 3. Reconciled Leaderboard RPC with Dynamic Sort Mode (GPA vs Points) & Strict Privacy
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
  v_sort_mode TEXT := 'gpa';
  v_leaderboard JSONB := '[]'::JSONB;
BEGIN
  -- Get requester role
  SELECT role::text INTO v_requester_role
  FROM public.profiles
  WHERE id = p_requester_id;

  v_is_staff := (v_requester_role IN ('super_admin', 'leader', 'evaluating_doctor'));

  -- Fetch configured sort mode from app_settings (default to 'gpa')
  SELECT COALESCE(value->>'mode', 'gpa') INTO v_sort_mode
  FROM public.app_settings
  WHERE key = 'leaderboard_sort_mode';

  IF v_sort_mode IS NULL OR v_sort_mode = '' THEN
    v_sort_mode := 'gpa';
  END IF;

  -- Calculate score and stats for all approved students
  WITH student_stats AS (
    SELECT
      p.id AS student_id,
      p.full_name,
      COALESCE(p.student_group, 'A') AS student_group,
      p.avatar_url,
      p.gpa,
      -- Attended Shifts
      COUNT(DISTINCT a.id) FILTER (WHERE a.status IN ('present', 'late', 'excused')) AS attended_shifts,
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
      COALESCE(SUM(d.deduction_value) FILTER (WHERE d.status = 'approved' AND d.action_type IN ('deduction', 'official_violation')), 0.0) AS approved_deductions
    FROM public.profiles p
    LEFT JOIN public.attendance a ON a.student_id = p.id
    LEFT JOIN public.quiz_attempts qa ON qa.student_id = p.id
    LEFT JOIN public.disciplinary_actions d ON d.student_id = p.id
    WHERE p.role = 'student' AND (p.is_approved = true OR p.registration_status = 'approved')
    GROUP BY p.id, p.full_name, p.student_group, p.avatar_url, p.gpa
  ),
  scored_students AS (
    SELECT
      s.*,
      LEAST(150.0, GREATEST(0.0,
        100.0 
        + (2.0 * s.attended_shifts)
        + ((s.avg_quiz_score / 100.0) * 15.0)
        + (5.0 * s.approved_rewards)
        - (2.0 * s.late_count)
        - (5.0 * s.absent_count)
        - (3.0 * s.approved_warnings)
        - s.approved_deductions
      )) AS calculated_score
    FROM student_stats s
  ),
  ranked_students AS (
    SELECT
      sc.*,
      ROW_NUMBER() OVER (
        ORDER BY 
          CASE WHEN v_sort_mode = 'gpa' THEN sc.gpa END DESC NULLS LAST,
          CASE WHEN v_sort_mode = 'points' THEN sc.calculated_score END DESC,
          CASE WHEN v_sort_mode = 'points' THEN sc.attended_shifts END DESC,
          sc.full_name ASC
      ) AS rank
    FROM scored_students sc
  )
  SELECT 
    CASE
      -- Staff (Admin, Leader, Doctor) receives full breakdown and reasoning
      WHEN v_is_staff THEN
        jsonb_agg(
          jsonb_build_object(
            'rank', rank,
            'student_id', student_id,
            'full_name', full_name,
            'student_group', student_group,
            'avatar_url', avatar_url,
            'gpa', gpa,
            'score', ROUND(calculated_score::numeric, 1),
            'attended_shifts', attended_shifts,
            'late_count', late_count,
            'absent_count', absent_count,
            'avg_quiz_score', ROUND(avg_quiz_score::numeric, 1),
            'approved_rewards', approved_rewards,
            'approved_warnings', approved_warnings,
            'approved_deductions', approved_deductions
          )
        )
      -- Students receive privacy-protected leaderboard with NO reason or formula details
      ELSE
        jsonb_agg(
          jsonb_build_object(
            'rank', rank,
            'student_id', student_id,
            'full_name', full_name,
            'student_group', student_group,
            'avatar_url', avatar_url
          )
        )
    END INTO v_leaderboard
  FROM ranked_students;

  RETURN jsonb_build_object(
    'requester_role', COALESCE(v_requester_role, 'anonymous'),
    'is_staff', v_is_staff,
    'sort_mode', v_sort_mode,
    'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb),
    'generated_at', NOW()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_leaderboard(UUID) TO authenticated, anon, service_role;
