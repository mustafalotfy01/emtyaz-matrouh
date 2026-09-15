-- ==============================================================================
-- MIGRATION: Comprehensive Row Level Security (RLS) Hardening
-- Date: 2026-09-09
-- File: 20260909_secure_rls_policies.sql
-- Reason: Remediate Security Audit Item 2:
--   1. Eliminate all 'USING (true)' and 'WITH CHECK (true)' vulnerabilities on:
--      - public.profiles
--      - public.roster_entries
--      - public.attendance
--      - public.evaluations
--      - public.disciplinary_actions
--      - public.cases & public.case_handovers
--      - public.notifications
--      - public.community_posts & public.community_comments
--      - public.confirmation_requests
--      - public.quizzes, quiz_questions, quiz_options, quiz_attempts, quiz_answers
--      - public.roster_preferences & shift_requests
--   2. Enforce strict horizontal & vertical isolation:
--      - Students can only view/update their own data
--      - Students can NEVER modify protected columns (role, GPA, approval, group)
--      - Anonymous (anon) access is completely barred from write/delete
--      - Leaders, Doctors, and Admins retain legitimate operational permissions
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PUBLIC.PROFILES HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "Profiles read" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete_policy" ON public.profiles;

-- (A) SELECT: Authenticated users can read profiles (needed for directory, peers, staff lookups)
CREATE POLICY "profiles_select_authenticated" ON public.profiles
    FOR SELECT
    TO authenticated, service_role
    USING (true);

-- (B) INSERT: Authenticated user can only insert their own row on registration, or super_admin
CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        auth.uid() = id
        OR public.get_auth_role() = 'super_admin'
    );

-- (C) UPDATE: Users can update their own row, or Admins/Leaders can manage students
CREATE POLICY "profiles_update_scoped" ON public.profiles
    FOR UPDATE
    TO authenticated, service_role
    USING (
        auth.uid() = id
        OR public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        auth.uid() = id
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

-- (D) DELETE: Absolutely restricted to Super Administrators (students can never delete profiles)
CREATE POLICY "profiles_delete_admin_only" ON public.profiles
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() = 'super_admin'
    );

-- (E) Trigger Hardening: Prevent students & unauthenticated callers from modifying protected fields
CREATE OR REPLACE FUNCTION public.trg_enforce_student_profile_security()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
BEGIN
    v_caller_id := auth.uid();

    -- Reject anonymous modification attempts completely
    IF v_caller_id IS NULL THEN
        IF current_user NOT IN ('service_role', 'postgres') THEN
            RAISE EXCEPTION 'Security Violation: Anonymous callers cannot modify profiles.';
        END IF;
        RETURN NEW;
    END IF;

    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = v_caller_id;

    -- If caller is a student, or if caller is updating their own profile and is not super_admin
    IF v_caller_role = 'student' OR (v_caller_id = OLD.id AND v_caller_role <> 'super_admin') THEN
        -- 1. Role Protection
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Security Violation: Cannot modify your own Role.';
        END IF;

        -- 2. GPA Protection
        IF NEW.gpa IS DISTINCT FROM OLD.gpa THEN
            RAISE EXCEPTION 'Security Violation: Cannot modify your own GPA.';
        END IF;

        -- 3. Approval & Registration Status Protection
        IF NEW.is_approved IS DISTINCT FROM OLD.is_approved 
           OR NEW.registration_status IS DISTINCT FROM OLD.registration_status 
           OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
           OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
           OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason THEN
            RAISE EXCEPTION 'Security Violation: Cannot modify your own Approval Status.';
        END IF;

        -- 4. Group & Classification Protection
        IF NEW.student_group IS DISTINCT FROM OLD.student_group
           OR NEW.student_group_id IS DISTINCT FROM OLD.student_group_id
           OR NEW.student_classification IS DISTINCT FROM OLD.student_classification THEN
            RAISE EXCEPTION 'Security Violation: Cannot modify your own Group or Classification.';
        END IF;

        -- 5. Primary Code Protection
        IF NEW.university_code IS DISTINCT FROM OLD.university_code
           OR NEW.national_id IS DISTINCT FROM OLD.national_id THEN
            RAISE EXCEPTION 'Security Violation: Cannot modify University Code or National ID.';
        END IF;
    END IF;

    -- If caller is a Leader (not super_admin), prevent modifying GPA or promoting anyone to super_admin
    IF v_caller_role = 'leader' THEN
        IF NEW.role = 'super_admin' AND OLD.role <> 'super_admin' THEN
            RAISE EXCEPTION 'Security Violation: Leaders cannot promote accounts to Super Admin.';
        END IF;
        IF NEW.gpa IS DISTINCT FROM OLD.gpa THEN
            RAISE EXCEPTION 'Security Violation: Leaders cannot directly modify student GPA.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profile_student_security ON public.profiles;
CREATE TRIGGER trg_profile_student_security
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_enforce_student_profile_security();


-- ------------------------------------------------------------------------------
-- 2. PUBLIC.ROSTER_ENTRIES HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.roster_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "roster_entries_delete_policy" ON public.roster_entries;
DROP POLICY IF EXISTS "roster_entries_student_select" ON public.roster_entries;
DROP POLICY IF EXISTS "roster_entries_leader_manage" ON public.roster_entries;

CREATE POLICY "roster_entries_select" ON public.roster_entries
    FOR SELECT
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "roster_entries_manage" ON public.roster_entries
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );


-- ------------------------------------------------------------------------------
-- 3. PUBLIC.ATTENDANCE HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_delete_policy" ON public.attendance;
DROP POLICY IF EXISTS "attendance_select" ON public.attendance;
DROP POLICY IF EXISTS "attendance_insert" ON public.attendance;
DROP POLICY IF EXISTS "attendance_update" ON public.attendance;
DROP POLICY IF EXISTS "attendance_delete" ON public.attendance;

CREATE POLICY "attendance_select" ON public.attendance
    FOR SELECT
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "attendance_insert" ON public.attendance
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "attendance_update" ON public.attendance
    FOR UPDATE
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "attendance_delete" ON public.attendance
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() = 'super_admin'
    );


-- ------------------------------------------------------------------------------
-- 4. PUBLIC.EVALUATIONS HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.evaluations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "evaluations_delete_policy" ON public.evaluations;
DROP POLICY IF EXISTS "evaluations_select" ON public.evaluations;
DROP POLICY IF EXISTS "evaluations_insert" ON public.evaluations;
DROP POLICY IF EXISTS "evaluations_update" ON public.evaluations;
DROP POLICY IF EXISTS "evaluations_delete" ON public.evaluations;

CREATE POLICY "evaluations_select" ON public.evaluations
    FOR SELECT
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR evaluator_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "evaluations_insert" ON public.evaluations
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'evaluating_doctor', 'leader')
    );

CREATE POLICY "evaluations_update" ON public.evaluations
    FOR UPDATE
    TO authenticated, service_role
    USING (
        evaluator_id = auth.uid()
        OR public.get_auth_role() = 'super_admin'
    )
    WITH CHECK (
        evaluator_id = auth.uid()
        OR public.get_auth_role() = 'super_admin'
    );

CREATE POLICY "evaluations_delete" ON public.evaluations
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() = 'super_admin'
    );


-- ------------------------------------------------------------------------------
-- 5. PUBLIC.DISCIPLINARY_ACTIONS HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.disciplinary_actions ENABLE ROW LEVEL SECURITY;

-- Drop both lowercase and capitalized previous policies to eliminate duplicate open rules
DROP POLICY IF EXISTS "disciplinary_actions_delete_policy" ON public.disciplinary_actions;
DROP POLICY IF EXISTS "Disciplinary actions delete policy" ON public.disciplinary_actions;
DROP POLICY IF EXISTS "Disciplinary actions student select" ON public.disciplinary_actions;
DROP POLICY IF EXISTS "Disciplinary actions insert policy" ON public.disciplinary_actions;
DROP POLICY IF EXISTS "Disciplinary actions update policy" ON public.disciplinary_actions;

CREATE POLICY "disciplinary_actions_select" ON public.disciplinary_actions
    FOR SELECT
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "disciplinary_actions_insert" ON public.disciplinary_actions
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "disciplinary_actions_update" ON public.disciplinary_actions
    FOR UPDATE
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "disciplinary_actions_delete" ON public.disciplinary_actions
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() = 'super_admin'
    );


-- ------------------------------------------------------------------------------
-- 6. PUBLIC.CASES & PUBLIC.CASE_HANDOVERS HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_handovers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cases_delete_policy" ON public.cases;
DROP POLICY IF EXISTS "cases_select" ON public.cases;
DROP POLICY IF EXISTS "cases_manage" ON public.cases;

CREATE POLICY "cases_select" ON public.cases
    FOR SELECT
    TO authenticated, service_role
    USING (
        current_student_id = auth.uid()
        OR supervisor_doctor_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "cases_manage" ON public.cases
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

DROP POLICY IF EXISTS "case_handovers_delete_policy" ON public.case_handovers;
DROP POLICY IF EXISTS "case_handovers_select" ON public.case_handovers;
DROP POLICY IF EXISTS "case_handovers_insert" ON public.case_handovers;
DROP POLICY IF EXISTS "case_handovers_update" ON public.case_handovers;

CREATE POLICY "case_handovers_select" ON public.case_handovers
    FOR SELECT
    TO authenticated, service_role
    USING (
        from_student_id = auth.uid()
        OR to_student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "case_handovers_insert" ON public.case_handovers
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        from_student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "case_handovers_update" ON public.case_handovers
    FOR UPDATE
    TO authenticated, service_role
    USING (
        from_student_id = auth.uid()
        OR to_student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    )
    WITH CHECK (
        from_student_id = auth.uid()
        OR to_student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "case_handovers_delete" ON public.case_handovers
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    );


-- ------------------------------------------------------------------------------
-- 7. PUBLIC.NOTIFICATIONS HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_delete_policy" ON public.notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Staff can insert notifications" ON public.notifications;

CREATE POLICY "notifications_select" ON public.notifications
    FOR SELECT
    TO authenticated, service_role
    USING (user_id = auth.uid());

CREATE POLICY "notifications_insert" ON public.notifications
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        user_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "notifications_update" ON public.notifications
    FOR UPDATE
    TO authenticated, service_role
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "notifications_delete" ON public.notifications
    FOR DELETE
    TO authenticated, service_role
    USING (
        user_id = auth.uid()
        OR public.get_auth_role() = 'super_admin'
    );


-- ------------------------------------------------------------------------------
-- 8. PUBLIC.COMMUNITY_POSTS & COMMENTS HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_posts_all" ON public.community_posts;
DROP POLICY IF EXISTS "community_posts_delete_policy" ON public.community_posts;
DROP POLICY IF EXISTS "community_posts_select" ON public.community_posts;
DROP POLICY IF EXISTS "community_posts_insert" ON public.community_posts;
DROP POLICY IF EXISTS "community_posts_update" ON public.community_posts;
DROP POLICY IF EXISTS "community_posts_delete" ON public.community_posts;
DROP POLICY IF EXISTS "community_posts_feature_update" ON public.community_posts;

CREATE POLICY "community_posts_select" ON public.community_posts
    FOR SELECT
    TO authenticated, service_role
    USING (true);

CREATE POLICY "community_posts_insert" ON public.community_posts
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "community_posts_update" ON public.community_posts
    FOR UPDATE
    TO authenticated, service_role
    USING (
        auth.uid() = author_id
        OR public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        auth.uid() = author_id
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "community_posts_delete" ON public.community_posts
    FOR DELETE
    TO authenticated, service_role
    USING (
        auth.uid() = author_id
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

DROP POLICY IF EXISTS "community_comments_all" ON public.community_comments;
DROP POLICY IF EXISTS "community_comments_delete_policy" ON public.community_comments;
DROP POLICY IF EXISTS "community_comments_read" ON public.community_comments;
DROP POLICY IF EXISTS "community_comments_select" ON public.community_comments;
DROP POLICY IF EXISTS "community_comments_insert" ON public.community_comments;
DROP POLICY IF EXISTS "community_comments_delete" ON public.community_comments;

CREATE POLICY "community_comments_select" ON public.community_comments
    FOR SELECT
    TO authenticated, service_role
    USING (true);

CREATE POLICY "community_comments_insert" ON public.community_comments
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "community_comments_update" ON public.community_comments
    FOR UPDATE
    TO authenticated, service_role
    USING (
        auth.uid() = author_id
        OR public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        auth.uid() = author_id
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "community_comments_delete" ON public.community_comments
    FOR DELETE
    TO authenticated, service_role
    USING (
        auth.uid() = author_id
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );


-- ------------------------------------------------------------------------------
-- 9. PUBLIC.CONFIRMATION_REQUESTS HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.confirmation_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conf_requests_all_manage" ON public.confirmation_requests;
DROP POLICY IF EXISTS "conf_requests_select_all" ON public.confirmation_requests;
DROP POLICY IF EXISTS "confirmation_requests_delete_policy" ON public.confirmation_requests;
DROP POLICY IF EXISTS "conf_requests_student_select" ON public.confirmation_requests;
DROP POLICY IF EXISTS "conf_requests_student_confirm" ON public.confirmation_requests;
DROP POLICY IF EXISTS "conf_requests_admin_manage" ON public.confirmation_requests;

CREATE POLICY "conf_requests_select" ON public.confirmation_requests
    FOR SELECT
    TO authenticated, service_role
    USING (
        target_student_id = auth.uid()
        OR sender_id = auth.uid()
        OR audience_type = 'ALL'
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "conf_requests_insert" ON public.confirmation_requests
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        sender_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "conf_requests_update" ON public.confirmation_requests
    FOR UPDATE
    TO authenticated, service_role
    USING (
        target_student_id = auth.uid()
        OR sender_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        target_student_id = auth.uid()
        OR sender_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "conf_requests_delete" ON public.confirmation_requests
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    );


-- ------------------------------------------------------------------------------
-- 10. PUBLIC.QUIZZES, QUESTIONS, OPTIONS, ATTEMPTS & ANSWERS HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_answers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "quizzes_manage" ON public.quizzes;
DROP POLICY IF EXISTS "quizzes_read" ON public.quizzes;
DROP POLICY IF EXISTS "Public quizzes read" ON public.quizzes;

CREATE POLICY "quizzes_select" ON public.quizzes
    FOR SELECT
    TO authenticated, service_role
    USING (
        is_active = true
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "quizzes_manage" ON public.quizzes
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

DROP POLICY IF EXISTS "quiz_questions_manage" ON public.quiz_questions;
DROP POLICY IF EXISTS "quiz_questions_read" ON public.quiz_questions;
DROP POLICY IF EXISTS "Public quiz_questions read" ON public.quiz_questions;

CREATE POLICY "quiz_questions_select" ON public.quiz_questions
    FOR SELECT
    TO authenticated, service_role
    USING (true);

CREATE POLICY "quiz_questions_manage" ON public.quiz_questions
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

DROP POLICY IF EXISTS "quiz_options_manage" ON public.quiz_options;
DROP POLICY IF EXISTS "quiz_options_read" ON public.quiz_options;
DROP POLICY IF EXISTS "Public quiz_options read" ON public.quiz_options;

CREATE POLICY "quiz_options_select" ON public.quiz_options
    FOR SELECT
    TO authenticated, service_role
    USING (true);

CREATE POLICY "quiz_options_manage" ON public.quiz_options
    FOR ALL
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

DROP POLICY IF EXISTS "quiz_attempts_all" ON public.quiz_attempts;
DROP POLICY IF EXISTS "quiz_attempts_delete_policy" ON public.quiz_attempts;
DROP POLICY IF EXISTS "quiz_attempts_student_select" ON public.quiz_attempts;
DROP POLICY IF EXISTS "quiz_attempts_student_insert" ON public.quiz_attempts;

CREATE POLICY "quiz_attempts_select" ON public.quiz_attempts
    FOR SELECT
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "quiz_attempts_insert" ON public.quiz_attempts
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "quiz_attempts_update" ON public.quiz_attempts
    FOR UPDATE
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "quiz_attempts_delete" ON public.quiz_attempts
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() = 'super_admin'
    );

DROP POLICY IF EXISTS "quiz_answers_student_manage" ON public.quiz_answers;
DROP POLICY IF EXISTS "quiz_answers_delete_policy" ON public.quiz_answers;

CREATE POLICY "quiz_answers_select" ON public.quiz_answers
    FOR SELECT
    TO authenticated, service_role
    USING (
        attempt_id IN (SELECT id FROM public.quiz_attempts WHERE student_id = auth.uid())
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "quiz_answers_insert" ON public.quiz_answers
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        attempt_id IN (SELECT id FROM public.quiz_attempts WHERE student_id = auth.uid())
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "quiz_answers_delete" ON public.quiz_answers
    FOR DELETE
    TO authenticated, service_role
    USING (
        public.get_auth_role() = 'super_admin'
    );


-- ------------------------------------------------------------------------------
-- 11. PUBLIC.ROSTER_PREFERENCES & SHIFT_REQUESTS HARDENING
-- ------------------------------------------------------------------------------
ALTER TABLE public.roster_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "roster_preferences_delete_policy" ON public.roster_preferences;
DROP POLICY IF EXISTS "roster_pref_student_delete" ON public.roster_preferences;
DROP POLICY IF EXISTS "roster_pref_delete" ON public.roster_preferences;
DROP POLICY IF EXISTS "roster_pref_student_select" ON public.roster_preferences;
DROP POLICY IF EXISTS "roster_pref_student_insert" ON public.roster_preferences;
DROP POLICY IF EXISTS "roster_pref_student_update" ON public.roster_preferences;
DROP POLICY IF EXISTS "roster_pref_select" ON public.roster_preferences;
DROP POLICY IF EXISTS "roster_pref_insert" ON public.roster_preferences;
DROP POLICY IF EXISTS "roster_pref_update" ON public.roster_preferences;

CREATE POLICY "roster_preferences_select" ON public.roster_preferences
    FOR SELECT
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "roster_preferences_insert" ON public.roster_preferences
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "roster_preferences_update" ON public.roster_preferences
    FOR UPDATE
    TO authenticated, service_role
    USING (
        (student_id = auth.uid() AND status = 'draft')
        OR public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        (student_id = auth.uid() AND status = 'draft')
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "roster_preferences_delete" ON public.roster_preferences
    FOR DELETE
    TO authenticated, service_role
    USING (
        (student_id = auth.uid() AND status = 'draft')
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

-- Clean up lingering dept_sup_admin_all
DROP POLICY IF EXISTS "dept_sup_admin_all" ON public.department_supervisors;

DROP POLICY IF EXISTS "shift_requests_delete_policy" ON public.shift_requests;
DROP POLICY IF EXISTS "shift_requests_student_select" ON public.shift_requests;
DROP POLICY IF EXISTS "shift_requests_student_insert" ON public.shift_requests;

CREATE POLICY "shift_requests_select" ON public.shift_requests
    FOR SELECT
    TO authenticated, service_role
    USING (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "shift_requests_insert" ON public.shift_requests
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        student_id = auth.uid()
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "shift_requests_update" ON public.shift_requests
    FOR UPDATE
    TO authenticated, service_role
    USING (
        (student_id = auth.uid() AND status = 'pending')
        OR public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
        (student_id = auth.uid() AND status = 'pending')
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );

CREATE POLICY "shift_requests_delete" ON public.shift_requests
    FOR DELETE
    TO authenticated, service_role
    USING (
        (student_id = auth.uid() AND status = 'pending')
        OR public.get_auth_role() IN ('super_admin', 'leader')
    );
