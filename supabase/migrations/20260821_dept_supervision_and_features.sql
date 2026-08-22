-- ==============================================================================
-- MIGRATION: Department Supervision & Extended Functional Features
-- Date: 2026-08-21
-- File: 20260821_dept_supervision_and_features.sql
-- ==============================================================================

-- 1. DEPARTMENT SUPERVISORS TABLE
CREATE TABLE IF NOT EXISTS public.department_supervisors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    male_capacity INT NOT NULL DEFAULT 0 CHECK (male_capacity >= 0),
    female_capacity INT NOT NULL DEFAULT 0 CHECK (female_capacity >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    assignment_status TEXT NOT NULL DEFAULT 'approved'
        CHECK (assignment_status IN ('draft', 'proposed', 'approved', 'rejected')),
    assigned_by UUID REFERENCES public.profiles(id),
    approved_by UUID REFERENCES public.profiles(id),
    approved_at TIMESTAMPTZ,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_active_dept_doctor UNIQUE (department_id, doctor_id)
);

CREATE INDEX IF NOT EXISTS idx_dept_sup_dept ON public.department_supervisors(department_id);
CREATE INDEX IF NOT EXISTS idx_dept_sup_doc ON public.department_supervisors(doctor_id);
CREATE INDEX IF NOT EXISTS idx_dept_sup_active ON public.department_supervisors(is_active) WHERE is_active = true;

-- 2. DEPARTMENTS EXTENSIONS
ALTER TABLE public.departments
    ADD COLUMN IF NOT EXISTS male_capacity INT DEFAULT 0 CHECK (male_capacity >= 0),
    ADD COLUMN IF NOT EXISTS female_capacity INT DEFAULT 0 CHECK (female_capacity >= 0),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. DISCIPLINARY ACTIONS EXTENSIONS & ADMIN BYPASS
ALTER TABLE public.disciplinary_actions
    ADD COLUMN IF NOT EXISTS created_by_role TEXT DEFAULT 'evaluating_doctor',
    ADD COLUMN IF NOT EXISTS admin_note TEXT,
    ADD COLUMN IF NOT EXISTS review_comment TEXT;

-- Update trigger function for doctor self-approval to allow super_admin direct creations
CREATE OR REPLACE FUNCTION public.trg_prevent_doctor_self_approval()
RETURNS TRIGGER AS $$
BEGIN
  -- Super admin direct action is permitted
  IF NEW.created_by_role = 'super_admin' THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'approved' AND NEW.approved_by IS NOT NULL AND NEW.approved_by = NEW.created_by THEN
    RAISE EXCEPTION 'Security Violation: Creators/Doctors cannot approve their own disciplinary actions.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.5. ROSTER PREFERENCES EXTENSIONS
ALTER TABLE public.roster_preferences
    ADD COLUMN IF NOT EXISTS shift_type TEXT;
ALTER TABLE public.roster_preferences
    DROP CONSTRAINT IF EXISTS roster_preferences_preference_type_check;

-- 4. COMMUNITY POSTS TABLE & EXTENSIONS
CREATE TABLE IF NOT EXISTS public.community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'general',
    image_url TEXT,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_featured BOOLEAN NOT NULL DEFAULT false,
    featured_at TIMESTAMPTZ,
    featured_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.community_posts
    ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS featured_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS featured_by UUID REFERENCES public.profiles(id);

CREATE INDEX IF NOT EXISTS idx_comm_posts_featured ON public.community_posts(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_comm_posts_created ON public.community_posts(created_at DESC);

-- 5. COMMUNITY COMMENTS TABLE
CREATE TABLE IF NOT EXISTS public.community_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comm_comments_post ON public.community_comments(post_id, created_at DESC);

-- 6. KNOWLEDGE ARTICLES EXTENSIONS
ALTER TABLE public.knowledge_articles
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS content_type TEXT CHECK (content_type IN ('procedure', 'disease', 'general')),
    ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS image_url TEXT;

CREATE INDEX IF NOT EXISTS idx_knowledge_type ON public.knowledge_articles(content_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_title ON public.knowledge_articles(title);

-- 7. QUIZ QUESTIONS EXTENSIONS
ALTER TABLE public.quiz_questions
    ADD COLUMN IF NOT EXISTS duration_seconds INT NOT NULL DEFAULT 30 CHECK (duration_seconds > 0),
    ADD COLUMN IF NOT EXISTS order_index INT DEFAULT 0;

-- 8. QUIZ ATTEMPTS EXTENSIONS
ALTER TABLE public.quiz_attempts
    ADD COLUMN IF NOT EXISTS total_questions INT,
    ADD COLUMN IF NOT EXISTS correct_count INT,
    ADD COLUMN IF NOT EXISTS incorrect_count INT,
    ADD COLUMN IF NOT EXISTS unanswered_count INT,
    ADD COLUMN IF NOT EXISTS completion_time_seconds INT;

-- 9. CONFIRMATION REQUESTS EXTENSIONS
ALTER TABLE public.confirmation_requests
    ADD COLUMN IF NOT EXISTS confirmed_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS confirmed_longitude DOUBLE PRECISION;

-- ==============================================================================
-- RLS POLICIES
-- ==============================================================================

-- department_supervisors RLS
ALTER TABLE public.department_supervisors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dept_sup_admin" ON public.department_supervisors;
CREATE POLICY "dept_sup_admin" ON public.department_supervisors
    FOR ALL USING (public.get_auth_role() = 'super_admin');

DROP POLICY IF EXISTS "dept_sup_leader_read" ON public.department_supervisors;
CREATE POLICY "dept_sup_leader_read" ON public.department_supervisors
    FOR SELECT USING (public.get_auth_role() IN ('leader', 'super_admin'));

DROP POLICY IF EXISTS "dept_sup_doctor_read" ON public.department_supervisors;
CREATE POLICY "dept_sup_doctor_read" ON public.department_supervisors
    FOR SELECT USING (
        doctor_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

DROP POLICY IF EXISTS "dept_sup_student_read" ON public.department_supervisors;
CREATE POLICY "dept_sup_student_read" ON public.department_supervisors
    FOR SELECT USING (is_active = true);

-- departments RLS
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "departments_read_all" ON public.departments;
CREATE POLICY "departments_read_all" ON public.departments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "departments_admin_manage" ON public.departments;
CREATE POLICY "departments_admin_manage" ON public.departments
    FOR ALL USING (public.get_auth_role() = 'super_admin');

-- community_comments RLS
ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_comments_read" ON public.community_comments;
CREATE POLICY "community_comments_read" ON public.community_comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "community_comments_insert" ON public.community_comments;
CREATE POLICY "community_comments_insert" ON public.community_comments
    FOR INSERT WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "community_comments_delete" ON public.community_comments;
CREATE POLICY "community_comments_delete" ON public.community_comments
    FOR DELETE USING (author_id = auth.uid() OR public.get_auth_role() IN ('super_admin', 'leader'));

-- Update community_posts policies to allow students to create posts
DROP POLICY IF EXISTS "community_posts_insert" ON public.community_posts;
CREATE POLICY "community_posts_insert" ON public.community_posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "community_posts_feature_update" ON public.community_posts;
CREATE POLICY "community_posts_feature_update" ON public.community_posts
    FOR UPDATE USING (
        auth.uid() = author_id
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

-- knowledge_articles RLS
ALTER TABLE public.knowledge_articles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "knowledge_articles_read" ON public.knowledge_articles;
CREATE POLICY "knowledge_articles_read" ON public.knowledge_articles
    FOR SELECT USING (is_published = true OR public.get_auth_role() IN ('super_admin', 'evaluating_doctor', 'leader'));

DROP POLICY IF EXISTS "knowledge_articles_manage" ON public.knowledge_articles;
CREATE POLICY "knowledge_articles_manage" ON public.knowledge_articles
    FOR ALL USING (public.get_auth_role() IN ('super_admin', 'evaluating_doctor'));

-- quizzes & questions RLS
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_answers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "quizzes_read" ON public.quizzes;
CREATE POLICY "quizzes_read" ON public.quizzes
    FOR SELECT USING (is_active = true OR public.get_auth_role() IN ('super_admin', 'evaluating_doctor', 'leader'));

DROP POLICY IF EXISTS "quizzes_manage" ON public.quizzes;
CREATE POLICY "quizzes_manage" ON public.quizzes
    FOR ALL USING (public.get_auth_role() IN ('super_admin', 'evaluating_doctor'));

DROP POLICY IF EXISTS "quiz_questions_read" ON public.quiz_questions;
CREATE POLICY "quiz_questions_read" ON public.quiz_questions
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "quiz_questions_manage" ON public.quiz_questions;
CREATE POLICY "quiz_questions_manage" ON public.quiz_questions
    FOR ALL USING (public.get_auth_role() IN ('super_admin', 'evaluating_doctor'));

DROP POLICY IF EXISTS "quiz_attempts_student_select" ON public.quiz_attempts;
CREATE POLICY "quiz_attempts_student_select" ON public.quiz_attempts
    FOR SELECT USING (student_id = auth.uid() OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor'));

DROP POLICY IF EXISTS "quiz_attempts_student_insert" ON public.quiz_attempts;
CREATE POLICY "quiz_attempts_student_insert" ON public.quiz_attempts
    FOR INSERT WITH CHECK (student_id = auth.uid() OR public.get_auth_role() IN ('super_admin', 'student'));

DROP POLICY IF EXISTS "quiz_answers_student_manage" ON public.quiz_answers;
CREATE POLICY "quiz_answers_student_manage" ON public.quiz_answers
    FOR ALL USING (true);

-- ==============================================================================
-- RPC FUNCTIONS
-- ==============================================================================

-- 1. Validate Department Capacity
CREATE OR REPLACE FUNCTION public.validate_department_capacity(
    p_department_id UUID,
    p_gender TEXT,
    p_additional INT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dept RECORD;
    v_current_male INT;
    v_current_female INT;
BEGIN
    SELECT * INTO v_dept FROM public.departments WHERE id = p_department_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'error', 'القسم غير موجود');
    END IF;

    -- Count active students assigned to this department via roster_entries or shift_requests
    SELECT 
        COUNT(DISTINCT re.student_id) FILTER (WHERE p.gender = 'male'),
        COUNT(DISTINCT re.student_id) FILTER (WHERE p.gender = 'female')
    INTO v_current_male, v_current_female
    FROM public.roster_entries re
    JOIN public.profiles p ON p.id = re.student_id
    WHERE re.department_id = p_department_id;

    v_current_male := COALESCE(v_current_male, 0);
    v_current_female := COALESCE(v_current_female, 0);

    IF p_gender = 'male' AND (v_current_male + p_additional) > v_dept.male_capacity THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'تجاوزت السعة الاستيعابية للطلاب الذكور في هذا القسم (الحد الأقصى: ' || v_dept.male_capacity || '، الحالي: ' || v_current_male || ')',
            'current_male', v_current_male,
            'current_female', v_current_female,
            'male_capacity', v_dept.male_capacity,
            'female_capacity', v_dept.female_capacity
        );
    END IF;

    IF p_gender = 'female' AND (v_current_female + p_additional) > v_dept.female_capacity THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'تجاوزت السعة الاستيعابية للطالبات الإناث في هذا القسم (الحد الأقصى: ' || v_dept.female_capacity || '، الحالي: ' || v_current_female || ')',
            'current_male', v_current_male,
            'current_female', v_current_female,
            'male_capacity', v_dept.male_capacity,
            'female_capacity', v_dept.female_capacity
        );
    END IF;

    RETURN jsonb_build_object(
        'valid', true,
        'current_male', v_current_male,
        'current_female', v_current_female,
        'male_capacity', v_dept.male_capacity,
        'female_capacity', v_dept.female_capacity,
        'remaining_male', GREATEST(0, v_dept.male_capacity - v_current_male),
        'remaining_female', GREATEST(0, v_dept.female_capacity - v_current_female)
    );
END;
$$;

-- 2. Get Department with Full Capacity & Supervisor Stats
CREATE OR REPLACE FUNCTION public.get_department_with_stats(
    p_department_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dept RECORD;
    v_sup RECORD;
    v_current_male INT;
    v_current_female INT;
BEGIN
    SELECT * INTO v_dept FROM public.departments WHERE id = p_department_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('found', false);
    END IF;

    -- Get active supervisor
    SELECT ds.*, p.full_name AS doctor_name, p.avatar_url AS doctor_avatar_url, p.university_code AS doctor_code
    INTO v_sup
    FROM public.department_supervisors ds
    JOIN public.profiles p ON p.id = ds.doctor_id
    WHERE ds.department_id = p_department_id AND ds.is_active = true
    LIMIT 1;

    -- Count current approved students
    SELECT 
        COUNT(DISTINCT re.student_id) FILTER (WHERE p.gender = 'male'),
        COUNT(DISTINCT re.student_id) FILTER (WHERE p.gender = 'female')
    INTO v_current_male, v_current_female
    FROM public.roster_entries re
    JOIN public.profiles p ON p.id = re.student_id
    WHERE re.department_id = p_department_id
      AND p.role = 'student'
      AND (p.is_approved = true OR p.registration_status = 'approved');

    v_current_male := COALESCE(v_current_male, 0);
    v_current_female := COALESCE(v_current_female, 0);

    RETURN jsonb_build_object(
        'found', true,
        'id', v_dept.id,
        'name_ar', v_dept.name_ar,
        'name_en', v_dept.name_en,
        'description', v_dept.description,
        'is_active', v_dept.is_active,
        'male_capacity', COALESCE(v_dept.male_capacity, 0),
        'female_capacity', COALESCE(v_dept.female_capacity, 0),
        'total_capacity', COALESCE(v_dept.male_capacity, 0) + COALESCE(v_dept.female_capacity, 0),
        'current_male', v_current_male,
        'current_female', v_current_female,
        'current_total', v_current_male + v_current_female,
        'remaining_male', GREATEST(0, COALESCE(v_dept.male_capacity, 0) - v_current_male),
        'remaining_female', GREATEST(0, COALESCE(v_dept.female_capacity, 0) - v_current_female),
        'remaining_total', GREATEST(0, (COALESCE(v_dept.male_capacity, 0) + COALESCE(v_dept.female_capacity, 0)) - (v_current_male + v_current_female)),
        'supervisor', CASE WHEN v_sup.id IS NOT NULL THEN jsonb_build_object(
            'id', v_sup.id,
            'doctor_id', v_sup.doctor_id,
            'doctor_name', v_sup.doctor_name,
            'doctor_avatar_url', v_sup.doctor_avatar_url,
            'doctor_code', v_sup.doctor_code,
            'male_capacity', v_sup.male_capacity,
            'female_capacity', v_sup.female_capacity,
            'is_active', v_sup.is_active,
            'assignment_status', v_sup.assignment_status,
            'assigned_at', v_sup.assigned_at
        ) ELSE NULL END
    );
END;
$$;

-- 3. Get Departments for Doctor
CREATE OR REPLACE FUNCTION public.get_departments_for_doctor(
    p_doctor_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
    v_rec RECORD;
BEGIN
    FOR v_rec IN (
        SELECT 
            d.id AS department_id,
            d.name_ar,
            d.name_en,
            d.description,
            ds.id AS supervisor_id,
            ds.male_capacity,
            ds.female_capacity,
            ds.assignment_status,
            ds.assigned_at,
            (
                SELECT COUNT(DISTINCT re.student_id)
                FROM public.roster_entries re
                JOIN public.profiles p ON p.id = re.student_id
                WHERE re.department_id = d.id 
                  AND p.gender = 'male'
                  AND p.role = 'student'
                  AND (p.is_approved = true OR p.registration_status = 'approved')
            ) AS current_male,
            (
                SELECT COUNT(DISTINCT re.student_id)
                FROM public.roster_entries re
                JOIN public.profiles p ON p.id = re.student_id
                WHERE re.department_id = d.id 
                  AND p.gender = 'female'
                  AND p.role = 'student'
                  AND (p.is_approved = true OR p.registration_status = 'approved')
            ) AS current_female,
            (
                SELECT COUNT(*)
                FROM public.evaluations ev
                WHERE ev.department_id = d.id AND ev.doctor_id = p_doctor_id
            ) AS evaluations_count,
            (
                SELECT COUNT(*)
                FROM public.case_handovers ch
                JOIN public.cases c ON c.id = ch.case_id
                WHERE c.department_id = d.id AND ch.status = 'pending'
            ) AS pending_handovers_count
        FROM public.department_supervisors ds
        JOIN public.departments d ON d.id = ds.department_id
        WHERE ds.doctor_id = p_doctor_id AND ds.is_active = true
    ) LOOP
        v_results := v_results || jsonb_build_object(
            'department_id', v_rec.department_id,
            'name_ar', v_rec.name_ar,
            'name_en', v_rec.name_en,
            'description', v_rec.description,
            'supervisor_id', v_rec.supervisor_id,
            'male_capacity', v_rec.male_capacity,
            'female_capacity', v_rec.female_capacity,
            'total_capacity', v_rec.male_capacity + v_rec.female_capacity,
            'current_male', COALESCE(v_rec.current_male, 0),
            'current_female', COALESCE(v_rec.current_female, 0),
            'current_total', COALESCE(v_rec.current_male, 0) + COALESCE(v_rec.current_female, 0),
            'remaining_male', GREATEST(0, v_rec.male_capacity - COALESCE(v_rec.current_male, 0)),
            'remaining_female', GREATEST(0, v_rec.female_capacity - COALESCE(v_rec.current_female, 0)),
            'remaining_total', GREATEST(0, (v_rec.male_capacity + v_rec.female_capacity) - (COALESCE(v_rec.current_male, 0) + COALESCE(v_rec.current_female, 0))),
            'evaluations_count', v_rec.evaluations_count,
            'pending_handovers_count', v_rec.pending_handovers_count,
            'assignment_status', v_rec.assignment_status,
            'assigned_at', v_rec.assigned_at
        );
    END LOOP;

    RETURN v_results;
END;
$$;

-- 4. Get Distribution Matrix for Leader & Admin
CREATE OR REPLACE FUNCTION public.get_distribution_matrix()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
    v_rec RECORD;
BEGIN
    FOR v_rec IN (
        SELECT 
            d.id AS department_id,
            d.name_ar AS department_name,
            d.is_active AS department_active,
            p.full_name AS doctor_name,
            p.id AS doctor_id,
            COALESCE(ds.male_capacity, d.male_capacity, 0) AS male_capacity,
            COALESCE(ds.female_capacity, d.female_capacity, 0) AS female_capacity,
            (
                SELECT COUNT(DISTINCT re.student_id)
                FROM public.roster_entries re
                JOIN public.profiles pr ON pr.id = re.student_id
                WHERE re.department_id = d.id 
                  AND pr.gender = 'male'
                  AND pr.role = 'student'
                  AND (pr.is_approved = true OR pr.registration_status = 'approved')
            ) AS current_male,
            (
                SELECT COUNT(DISTINCT re.student_id)
                FROM public.roster_entries re
                JOIN public.profiles pr ON pr.id = re.student_id
                WHERE re.department_id = d.id 
                  AND pr.gender = 'female'
                  AND pr.role = 'student'
                  AND (pr.is_approved = true OR pr.registration_status = 'approved')
            ) AS current_female,
            COALESCE(ds.assignment_status, 'approved') AS assignment_status
        FROM public.departments d
        LEFT JOIN public.department_supervisors ds ON ds.department_id = d.id AND ds.is_active = true
        LEFT JOIN public.profiles p ON p.id = ds.doctor_id
        WHERE d.is_active = true
        ORDER BY d.name_ar ASC
    ) LOOP
        v_results := v_results || jsonb_build_object(
            'department_id', v_rec.department_id,
            'department_name', v_rec.department_name,
            'doctor_id', v_rec.doctor_id,
            'doctor_name', COALESCE(v_rec.doctor_name, 'لم يتم التعيين'),
            'male_capacity', v_rec.male_capacity,
            'female_capacity', v_rec.female_capacity,
            'total_capacity', v_rec.male_capacity + v_rec.female_capacity,
            'current_male', COALESCE(v_rec.current_male, 0),
            'current_female', COALESCE(v_rec.current_female, 0),
            'current_total', COALESCE(v_rec.current_male, 0) + COALESCE(v_rec.current_female, 0),
            'remaining_male', GREATEST(0, v_rec.male_capacity - COALESCE(v_rec.current_male, 0)),
            'remaining_female', GREATEST(0, v_rec.female_capacity - COALESCE(v_rec.current_female, 0)),
            'remaining_total', GREATEST(0, (v_rec.male_capacity + v_rec.female_capacity) - (COALESCE(v_rec.current_male, 0) + COALESCE(v_rec.current_female, 0))),
            'assignment_status', v_rec.assignment_status
        );
    END LOOP;

    RETURN v_results;
END;
$$;

-- 5. Reconciled Leaderboard with Alphabetical Fallback & Deterministic Tiebreak
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
  v_has_active_points BOOLEAN := false;
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
      -- Base Score is 100 + activities
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
      (
        s.attended_shifts > 0 
        OR s.avg_quiz_score > 0 
        OR s.approved_rewards > 0 
        OR s.late_count > 0 
        OR s.absent_count > 0 
        OR s.approved_warnings > 0 
        OR s.approved_deductions > 0
      ) AS has_activity
    FROM student_stats s
  ),
  ranked_students AS (
    SELECT
      sc.*,
      ROW_NUMBER() OVER (
        ORDER BY 
          sc.calculated_score DESC,
          sc.attended_shifts DESC,
          sc.full_name ASC
      ) AS rank
    FROM scored_students sc
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
  FROM ranked_students;

  RETURN jsonb_build_object(
    'requester_role', COALESCE(v_requester_role, 'anonymous'),
    'is_staff', v_is_staff,
    'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb),
    'generated_at', NOW()
  );
END;
$$;

-- Grant permissions
GRANT ALL ON public.department_supervisors TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.community_comments TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.departments TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.knowledge_articles TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.quizzes TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.quiz_questions TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.quiz_attempts TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.quiz_answers TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_department_capacity(UUID, TEXT, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_department_with_stats(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_departments_for_doctor(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_distribution_matrix() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_student_leaderboard(UUID) TO authenticated, service_role;
