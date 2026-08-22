-- ==============================================================================
-- MIGRATION: Nurse Matrouh Extended Features & Server Security Foundation
-- Date: 2026-08-21
-- File: 20260821_extended_features.sql
-- Description:
--   1. profiles.avatar_url column
--   2. app_versions table & RLS policies
--   3. confirmation_requests table & RLS policies (Realtime enabled)
--   4. community_posts table & RLS policies (Realtime enabled)
--   5. case_handovers extensions (image_urls, status, acknowledged_at, rejection_reason)
--   6. Storage buckets & RLS policies ('profile-avatars', 'handover-attachments')
--   7. Doctor self-approval prevention trigger on disciplinary_actions
--   8. validate_monthly_schedule_36h RPC (Saturday-Friday 36h validation)
--   9. validate_student_group_selection RPC (11 peers, male <= 4, female <= 7)
--  10. get_student_leaderboard RPC (Reconciled score formula & privacy filtering)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PROFILES: AVATAR URL EXTENSION
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- ------------------------------------------------------------------------------
-- 2. APP VERSIONS TABLE & SECURITY POLICIES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_name TEXT NOT NULL,
    version_code INT UNIQUE NOT NULL,
    apk_download_url TEXT NOT NULL,
    release_notes TEXT,
    force_update BOOLEAN NOT NULL DEFAULT false,
    minimum_supported_version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    release_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_versions_code ON public.app_versions(version_code DESC);
CREATE INDEX IF NOT EXISTS idx_app_versions_active ON public.app_versions(is_active) WHERE is_active = true;

ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_versions_select_policy" ON public.app_versions;
CREATE POLICY "app_versions_select_policy" ON public.app_versions
  FOR SELECT USING (is_active = true OR public.get_auth_role() = 'super_admin');

DROP POLICY IF EXISTS "app_versions_admin_manage" ON public.app_versions;
CREATE POLICY "app_versions_admin_manage" ON public.app_versions
  FOR ALL USING (public.get_auth_role() = 'super_admin');

-- Seed initial app version (1.0.0+1)
INSERT INTO public.app_versions (version_name, version_code, apk_download_url, release_notes, force_update, minimum_supported_version, is_active)
VALUES ('1.0.0', 1, 'https://github.com/mustafalotfy01/emtyaz-matrouh/releases/latest', 'الإصدار الرسمي الأولي لتطبيق امتياز مطروح للتمريض', false, 1, true)
ON CONFLICT (version_code) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 3. CONFIRMATION REQUESTS TABLE (ADMIN LOCK / FINGERPRINT)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.confirmation_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    audience_type TEXT NOT NULL CHECK (audience_type IN ('ALL', 'GROUP_A', 'GROUP_B', 'SPECIFIC_STUDENT')),
    target_student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'طلب تأكيد التواجد والبصمة',
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'expired')),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    device_metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conf_req_target ON public.confirmation_requests(target_student_id);
CREATE INDEX IF NOT EXISTS idx_conf_req_status ON public.confirmation_requests(status);
CREATE INDEX IF NOT EXISTS idx_conf_req_sent ON public.confirmation_requests(sent_at DESC);

ALTER TABLE public.confirmation_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conf_requests_student_select" ON public.confirmation_requests;
CREATE POLICY "conf_requests_student_select" ON public.confirmation_requests
  FOR SELECT USING (
    target_student_id = auth.uid()
    OR audience_type = 'ALL'
    OR (audience_type = 'GROUP_A' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND student_group = 'A'))
    OR (audience_type = 'GROUP_B' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND student_group = 'B'))
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "conf_requests_student_confirm" ON public.confirmation_requests;
CREATE POLICY "conf_requests_student_confirm" ON public.confirmation_requests
  FOR UPDATE USING (
    (target_student_id = auth.uid() OR public.get_auth_role() = 'student')
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "conf_requests_admin_manage" ON public.confirmation_requests;
CREATE POLICY "conf_requests_admin_manage" ON public.confirmation_requests
  FOR ALL USING (public.get_auth_role() IN ('super_admin', 'leader'));

-- ------------------------------------------------------------------------------
-- 4. COMMUNITY POSTS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('announcement', 'case_study', 'emergency', 'shift_update', 'educational', 'general')),
    image_url TEXT,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_community_posts_created ON public.community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_pinned ON public.community_posts(is_pinned) WHERE is_pinned = true;

ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_posts_select" ON public.community_posts;
CREATE POLICY "community_posts_select" ON public.community_posts
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "community_posts_insert" ON public.community_posts;
CREATE POLICY "community_posts_insert" ON public.community_posts
  FOR INSERT WITH CHECK (
    auth.uid() = author_id
    AND public.get_auth_role() IN ('leader', 'evaluating_doctor', 'super_admin')
  );

DROP POLICY IF EXISTS "community_posts_update" ON public.community_posts;
CREATE POLICY "community_posts_update" ON public.community_posts
  FOR UPDATE USING (
    auth.uid() = author_id
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "community_posts_delete" ON public.community_posts;
CREATE POLICY "community_posts_delete" ON public.community_posts
  FOR DELETE USING (
    auth.uid() = author_id
    OR public.get_auth_role() = 'super_admin'
  );

-- ------------------------------------------------------------------------------
-- 5. CASE HANDOVERS EXTENSIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.case_handovers
  ADD COLUMN IF NOT EXISTS image_urls TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS handover_status TEXT DEFAULT 'pending' CHECK (handover_status IN ('pending', 'completed', 'rejected', 'missing')),
  ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.case_handovers ENABLE ROW LEVEL SECURITY;

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
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

-- ------------------------------------------------------------------------------
-- 6. STORAGE BUCKETS & POLICIES
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public) VALUES
  ('profile-avatars', 'profile-avatars', true),
  ('handover-attachments', 'handover-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- profile-avatars policies
DROP POLICY IF EXISTS "Public avatars read" ON storage.objects;
CREATE POLICY "Public avatars read" ON storage.objects
  FOR SELECT USING (bucket_id = 'profile-avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profile-avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'profile-avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- handover-attachments policies (Private)
DROP POLICY IF EXISTS "Handover attachments read" ON storage.objects;
CREATE POLICY "Handover attachments read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'handover-attachments'
    AND auth.role() = 'authenticated'
  );

DROP POLICY IF EXISTS "Handover attachments upload" ON storage.objects;
CREATE POLICY "Handover attachments upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'handover-attachments'
    AND auth.role() = 'authenticated'
  );

-- ------------------------------------------------------------------------------
-- 7. DOCTOR SELF-APPROVAL PREVENTION TRIGGER
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_prevent_doctor_self_approval()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND NEW.approved_by IS NOT NULL AND NEW.approved_by = NEW.created_by THEN
    RAISE EXCEPTION 'Security Violation: Creators/Doctors cannot approve their own disciplinary actions.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS check_disciplinary_self_approval ON public.disciplinary_actions;
CREATE TRIGGER check_disciplinary_self_approval
  BEFORE UPDATE OR INSERT ON public.disciplinary_actions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_prevent_doctor_self_approval();

-- ------------------------------------------------------------------------------
-- 8. RPC: VALIDATE MONTHLY SCHEDULE 36-HOUR RULE (SATURDAY TO FRIDAY WEEKS)
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
  -- Create temporary table for submitted shifts in this validation session
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
        WHEN 'evening' THEN 6
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
-- 9. RPC: VALIDATE STUDENT GROUP SELECTION (11 PEERS, MALE <= 4, FEMALE <= 7)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_student_group_selection(
  p_student_id UUID,
  p_selected_peer_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_group TEXT;
  v_selected_count INT;
  v_male_count INT;
  v_female_count INT;
  v_foreign_group_count INT;
BEGIN
  -- 1. Check Student Group
  SELECT student_group INTO v_student_group
  FROM public.profiles
  WHERE id = p_student_id;

  IF v_student_group IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'error', 'الطالب غير مسجل في أي مجموعة');
  END IF;

  -- 2. Check Selection Length
  v_selected_count := COALESCE(array_length(p_selected_peer_ids, 1), 0);
  IF v_selected_count != 11 THEN
    RETURN jsonb_build_object(
      'valid', false, 
      'error', 'يجب اختيار 11 اسم زميل بالضبط (العدد المختار: ' || v_selected_count || ')'
    );
  END IF;

  -- 3. Check Self Inclusion
  IF p_student_id = ANY(p_selected_peer_ids) THEN
    RETURN jsonb_build_object('valid', false, 'error', 'لا يمكن اختيار اسمك ضمن قائمة الزملاء');
  END IF;

  -- 4. Check for Duplicates
  IF (SELECT COUNT(DISTINCT id) FROM unnest(p_selected_peer_ids) AS id) != 11 THEN
    RETURN jsonb_build_object('valid', false, 'error', 'القائمة تحتوي على أسماء مكررة');
  END IF;

  -- 5. Count Genders
  SELECT 
    COUNT(*) FILTER (WHERE gender = 'male'),
    COUNT(*) FILTER (WHERE gender = 'female'),
    COUNT(*) FILTER (WHERE student_group != v_student_group OR role != 'student')
  INTO v_male_count, v_female_count, v_foreign_group_count
  FROM public.profiles
  WHERE id = ANY(p_selected_peer_ids);

  IF v_foreign_group_count > 0 THEN
    RETURN jsonb_build_object('valid', false, 'error', 'تم اختيار طلاب من خارج مجموعتك الدراسية (' || v_student_group || ')');
  END IF;

  IF v_male_count > 4 THEN
    RETURN jsonb_build_object(
      'valid', false, 
      'error', 'تجاوزت الحد الأقصى للطلاب الذكور (المختار: ' || v_male_count || '، الحد الأقصى: 4)'
    );
  END IF;

  IF v_female_count > 7 THEN
    RETURN jsonb_build_object(
      'valid', false, 
      'error', 'تجاوزت الحد الأقصى للطالبات الإناث (المختار: ' || v_female_count || '، الحد الأقصى: 7)'
    );
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'male_count', v_male_count,
    'female_count', v_female_count,
    'total_selected', 11,
    'student_group', v_student_group,
    'message', 'اختيار المجموعة مكتمل وصحيح وفق الضوابط'
  );
END;
$$;

-- ------------------------------------------------------------------------------
-- 10. RPC: GET STUDENT LEADERBOARD (RECONCILED SCORING & PRIVACY)
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
    GROUP BY p.id, p.full_name, p.student_group, p.avatar_url
  ),
  scored_students AS (
    SELECT
      s.*,
      -- Reconciled Exact Formula:
      -- clamp(100 + (2 * attended) + ((avg_quiz/100) * 15) + (5 * rewards) - (2 * late) - (5 * absent) - (3 * warnings) - deductions, 0, 150)
      LEAST(150.0, GREATEST(0.0,
        100.0 
        + (2.0 * s.attended_shifts)
        + ((s.avg_quiz_score / 100.0) * 15.0)
        + (5.0 * s.approved_rewards)
        - (2.0 * s.late_count)
        - (5.0 * s.absent_count)
        - (3.0 * s.approved_warnings)
        - s.approved_deductions
      )) AS calculated_score,
      ROW_NUMBER() OVER (
        ORDER BY 
          LEAST(150.0, GREATEST(0.0,
            100.0 
            + (2.0 * s.attended_shifts)
            + ((s.avg_quiz_score / 100.0) * 15.0)
            + (5.0 * s.approved_rewards)
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
            'late_count', late_count,
            'absent_count', absent_count,
            'avg_quiz_score', ROUND(avg_quiz_score::numeric, 1),
            'approved_rewards', approved_rewards,
            'approved_warnings', approved_warnings,
            'approved_deductions', approved_deductions
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
            'attended_shifts', attended_shifts
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
-- 11. GRANT EXECUTE ON ALL NEW FUNCTIONS
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.validate_monthly_schedule_36h(UUID, TEXT, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_student_group_selection(UUID, UUID[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_student_leaderboard(UUID) TO authenticated, service_role;
GRANT ALL ON public.app_versions TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.confirmation_requests TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.community_posts TO postgres, anon, authenticated, service_role;
