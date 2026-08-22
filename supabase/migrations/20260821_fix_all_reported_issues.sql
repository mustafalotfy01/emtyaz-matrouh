-- ==============================================================================
-- MIGRATION: Comprehensive Fix for Nurse Matrouh Database
-- Date: 2026-08-21
-- File: 20260821_fix_all_reported_issues.sql
-- ==============================================================================

-- 1. PROFILES TABLE EXTENSIONS (Fix avatar_url and other columns)
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS gpa NUMERIC(4,2),
    ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS registration_status TEXT DEFAULT 'approved',
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
    ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id),
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- Drop NOT NULL constraints on optional profile columns
ALTER TABLE public.profiles
    ALTER COLUMN phone_number DROP NOT NULL,
    ALTER COLUMN emergency_contact DROP NOT NULL,
    ALTER COLUMN residence_address DROP NOT NULL,
    ALTER COLUMN university_code DROP NOT NULL;

-- Drop legacy student group division if present
ALTER TABLE public.profiles DROP COLUMN IF EXISTS student_group;

-- Bulletproof handle_new_user trigger for Auth registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    university_code,
    phone_number,
    emergency_contact,
    residence_address,
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
    COALESCE(new.raw_user_meta_data->>'phone_number', ''),
    COALESCE(new.raw_user_meta_data->>'emergency_contact', ''),
    COALESCE(new.raw_user_meta_data->>'residence_address', ''),
    COALESCE(new.raw_user_meta_data->>'role', 'student'),
    COALESCE(new.raw_user_meta_data->>'registration_status', 'pending'),
    COALESCE((new.raw_user_meta_data->>'is_approved')::BOOLEAN, false),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    university_code = EXCLUDED.university_code,
    updated_at = NOW();

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. APP VERSIONS TABLE
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

-- 3. CONFIRMATION REQUESTS TABLE (Fingerprint & Instant Attendance)
CREATE TABLE IF NOT EXISTS public.confirmation_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    audience_type TEXT NOT NULL,
    target_student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'طلب تأكيد التواجد والبصمة',
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    device_metadata JSONB DEFAULT '{}'::jsonb,
    confirmed_latitude DOUBLE PRECISION,
    confirmed_longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Drop legacy check constraint if exists
ALTER TABLE public.confirmation_requests DROP CONSTRAINT IF EXISTS confirmation_requests_audience_type_check;

CREATE INDEX IF NOT EXISTS idx_conf_req_target ON public.confirmation_requests(target_student_id);
CREATE INDEX IF NOT EXISTS idx_conf_req_status ON public.confirmation_requests(status);
CREATE INDEX IF NOT EXISTS idx_conf_req_sent ON public.confirmation_requests(sent_at DESC);

-- 4. COMMUNITY POSTS & COMMENTS TABLES
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

CREATE INDEX IF NOT EXISTS idx_community_posts_created ON public.community_posts(created_at DESC);

CREATE TABLE IF NOT EXISTS public.community_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_community_comments_post ON public.community_comments(post_id, created_at DESC);

-- 5. DEPARTMENTS EXTENSIONS
ALTER TABLE public.departments
    ADD COLUMN IF NOT EXISTS male_capacity INT DEFAULT 0 CHECK (male_capacity >= 0),
    ADD COLUMN IF NOT EXISTS female_capacity INT DEFAULT 0 CHECK (female_capacity >= 0),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 6. DEPARTMENT SUPERVISORS TABLE
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

-- 7. DISCIPLINARY ACTIONS EXTENSIONS
ALTER TABLE public.disciplinary_actions
    ADD COLUMN IF NOT EXISTS created_by_role TEXT DEFAULT 'evaluating_doctor',
    ADD COLUMN IF NOT EXISTS admin_note TEXT,
    ADD COLUMN IF NOT EXISTS review_comment TEXT;

-- 8. KNOWLEDGE ARTICLES EXTENSIONS
ALTER TABLE public.knowledge_articles
    ADD COLUMN IF NOT EXISTS content_type TEXT CHECK (content_type IN ('procedure', 'disease', 'general')),
    ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS image_url TEXT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 9. QUIZZES & QUESTIONS EXTENSIONS
ALTER TABLE public.quiz_questions
    ADD COLUMN IF NOT EXISTS duration_seconds INT NOT NULL DEFAULT 30 CHECK (duration_seconds > 0),
    ADD COLUMN IF NOT EXISTS order_index INT DEFAULT 0;

ALTER TABLE public.quiz_attempts
    ADD COLUMN IF NOT EXISTS total_questions INT,
    ADD COLUMN IF NOT EXISTS correct_count INT,
    ADD COLUMN IF NOT EXISTS incorrect_count INT,
    ADD COLUMN IF NOT EXISTS unanswered_count INT,
    ADD COLUMN IF NOT EXISTS completion_time_seconds INT;

-- ==============================================================================
-- RPC FUNCTIONS
-- ==============================================================================

-- Helper for user role
CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT role::text FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- 1. Get Departments for Doctor
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
            COALESCE(ds.male_capacity, d.male_capacity, 0) AS male_capacity,
            COALESCE(ds.female_capacity, d.female_capacity, 0) AS female_capacity,
            ds.assignment_status,
            ds.assigned_at,
            (
                SELECT COUNT(DISTINCT re.student_id)
                FROM public.roster_entries re
                JOIN public.profiles p ON p.id = re.student_id
                WHERE re.department_id = d.id AND p.gender = 'male'
            ) AS current_male,
            (
                SELECT COUNT(DISTINCT re.student_id)
                FROM public.roster_entries re
                JOIN public.profiles p ON p.id = re.student_id
                WHERE re.department_id = d.id AND p.gender = 'female'
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

    -- Count current students
    SELECT 
        COUNT(DISTINCT re.student_id) FILTER (WHERE p.gender = 'male'),
        COUNT(DISTINCT re.student_id) FILTER (WHERE p.gender = 'female')
    INTO v_current_male, v_current_female
    FROM public.roster_entries re
    JOIN public.profiles p ON p.id = re.student_id
    WHERE re.department_id = p_department_id;

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

-- 3. Get Distribution Matrix
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
                JOIN public.profiles p2 ON p2.id = re.student_id
                WHERE re.department_id = d.id AND p2.gender = 'male'
            ) AS current_male,
            (
                SELECT COUNT(DISTINCT re.student_id)
                FROM public.roster_entries re
                JOIN public.profiles p2 ON p2.id = re.student_id
                WHERE re.department_id = d.id AND p2.gender = 'female'
            ) AS current_female
        FROM public.departments d
        LEFT JOIN public.department_supervisors ds ON ds.department_id = d.id AND ds.is_active = true
        LEFT JOIN public.profiles p ON p.id = ds.doctor_id
        ORDER BY d.name_ar ASC
    ) LOOP
        v_results := v_results || jsonb_build_object(
            'department_id', v_rec.department_id,
            'department_name', v_rec.department_name,
            'department_active', v_rec.department_active,
            'doctor_name', v_rec.doctor_name,
            'doctor_id', v_rec.doctor_id,
            'male_capacity', v_rec.male_capacity,
            'female_capacity', v_rec.female_capacity,
            'total_capacity', v_rec.male_capacity + v_rec.female_capacity,
            'current_male', COALESCE(v_rec.current_male, 0),
            'current_female', COALESCE(v_rec.current_female, 0),
            'current_total', COALESCE(v_rec.current_male, 0) + COALESCE(v_rec.current_female, 0),
            'remaining_male', GREATEST(0, v_rec.male_capacity - COALESCE(v_rec.current_male, 0)),
            'remaining_female', GREATEST(0, v_rec.female_capacity - COALESCE(v_rec.current_female, 0)),
            'remaining_total', GREATEST(0, (v_rec.male_capacity + v_rec.female_capacity) - (COALESCE(v_rec.current_male, 0) + COALESCE(v_rec.current_female, 0)))
        );
    END LOOP;

    RETURN v_results;
END;
$$;

-- Grant execute permissions to all users
GRANT EXECUTE ON FUNCTION public.get_departments_for_doctor(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_department_with_stats(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_distribution_matrix() TO authenticated, anon, service_role;

-- ==============================================================================
-- RLS POLICIES
-- ==============================================================================

ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.confirmation_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.department_supervisors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;

-- Community Posts & Comments Policies
DROP POLICY IF EXISTS "community_posts_all" ON public.community_posts;
CREATE POLICY "community_posts_all" ON public.community_posts
    FOR ALL USING (true);

DROP POLICY IF EXISTS "community_comments_all" ON public.community_comments;
CREATE POLICY "community_comments_all" ON public.community_comments
    FOR ALL USING (true);

-- Confirmation Requests Policies (Fingerprint)
DROP POLICY IF EXISTS "conf_requests_select_all" ON public.confirmation_requests;
CREATE POLICY "conf_requests_select_all" ON public.confirmation_requests
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "conf_requests_all_manage" ON public.confirmation_requests;
CREATE POLICY "conf_requests_all_manage" ON public.confirmation_requests
    FOR ALL USING (true);

-- Department Supervisors Policies
DROP POLICY IF EXISTS "dept_sup_select_all" ON public.department_supervisors;
CREATE POLICY "dept_sup_select_all" ON public.department_supervisors
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "dept_sup_admin_all" ON public.department_supervisors;
CREATE POLICY "dept_sup_admin_all" ON public.department_supervisors
    FOR ALL USING (true);

-- Knowledge Articles Policies
DROP POLICY IF EXISTS "knowledge_articles_read" ON public.knowledge_articles;
CREATE POLICY "knowledge_articles_read" ON public.knowledge_articles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "knowledge_articles_manage" ON public.knowledge_articles;
CREATE POLICY "knowledge_articles_manage" ON public.knowledge_articles
    FOR ALL USING (true);

-- Quizzes Policies
DROP POLICY IF EXISTS "quizzes_read" ON public.quizzes;
CREATE POLICY "quizzes_read" ON public.quizzes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "quizzes_manage" ON public.quizzes;
CREATE POLICY "quizzes_manage" ON public.quizzes
    FOR ALL USING (true);

DROP POLICY IF EXISTS "quiz_questions_read" ON public.quiz_questions;
CREATE POLICY "quiz_questions_read" ON public.quiz_questions
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "quiz_questions_manage" ON public.quiz_questions;
CREATE POLICY "quiz_questions_manage" ON public.quiz_questions
    FOR ALL USING (true);

DROP POLICY IF EXISTS "quiz_attempts_all" ON public.quiz_attempts;
CREATE POLICY "quiz_attempts_all" ON public.quiz_attempts
    FOR ALL USING (true);

-- Profiles Delete Policy
DROP POLICY IF EXISTS "profiles_delete_policy" ON public.profiles;
CREATE POLICY "profiles_delete_policy" ON public.profiles
    FOR DELETE USING (true);

-- 10. RPC: Permanent and Clean Student Deletion Cascade
CREATE OR REPLACE FUNCTION public.delete_student_account(p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 1. Delete dependent records across all modules
    DELETE FROM public.quiz_answers WHERE attempt_id IN (SELECT id FROM public.quiz_attempts WHERE student_id = p_student_id);
    DELETE FROM public.quiz_attempts WHERE student_id = p_student_id;
    DELETE FROM public.attendance WHERE student_id = p_student_id;
    DELETE FROM public.roster_entries WHERE student_id = p_student_id;
    DELETE FROM public.roster_preferences WHERE student_id = p_student_id;
    DELETE FROM public.notifications WHERE user_id = p_student_id;
    DELETE FROM public.case_handovers WHERE from_student_id = p_student_id OR to_student_id = p_student_id;
    DELETE FROM public.cases WHERE student_id = p_student_id;
    DELETE FROM public.evaluations WHERE student_id = p_student_id;
    DELETE FROM public.disciplinary_actions WHERE student_id = p_student_id;
    DELETE FROM public.confirmation_requests WHERE target_student_id = p_student_id OR sender_id = p_student_id;
    DELETE FROM public.community_comments WHERE author_id = p_student_id;
    DELETE FROM public.community_posts WHERE author_id = p_student_id;
    DELETE FROM public.audit_logs WHERE user_id = p_student_id;
    
    -- Nullify any reviewer references
    UPDATE public.profiles SET reviewed_by = NULL WHERE reviewed_by = p_student_id;
    
    -- 2. Delete profile
    DELETE FROM public.profiles WHERE id = p_student_id;
    
    -- 3. Delete from auth.users if exists
    BEGIN
        DELETE FROM auth.users WHERE id = p_student_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    
    RETURN true;
EXCEPTION WHEN OTHERS THEN
    RETURN false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_student_account(UUID) TO authenticated, anon, service_role;
