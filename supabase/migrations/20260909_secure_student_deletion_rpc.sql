-- ==============================================================================
-- MIGRATION: Secure Student Deletion RPC (Security Hardening)
-- Date: 2026-09-09
-- File: 20260909_secure_student_deletion_rpc.sql
-- Reason: Fix Critical Security Vulnerability:
--   1. Revoke unauthenticated execution from 'anon' and 'public'.
--   2. Enforce caller authorization: only authenticated Super Admins & Leaders can execute.
--   3. Restrict target scope: prevent deletion of faculty/admins (students only).
--   4. Audit all account purges to public.audit_logs.
-- ==============================================================================

-- 1. Revoke public/anon execute permissions
REVOKE EXECUTE ON FUNCTION public.delete_student_account(TEXT) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.delete_student_account(UUID) FROM anon, public;

-- 2. Grant execute only to authenticated users and service_role
GRANT EXECUTE ON FUNCTION public.delete_student_account(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_student_account(UUID) TO authenticated, service_role;

-- 3. Replace delete_student_account(TEXT) with strict authorization & target guards
CREATE OR REPLACE FUNCTION public.delete_student_account(p_student_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_target_user_id UUID := NULL;
    v_target_role TEXT := NULL;
    v_clean_id TEXT;
BEGIN
    v_clean_id := TRIM(p_student_id);
    IF v_clean_id IS NULL OR v_clean_id = '' THEN
        RAISE EXCEPTION 'Invalid student identifier provided.';
    END IF;

    -- A. Enforce Caller Authentication & Authorization
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        SELECT role::text INTO v_caller_role
        FROM public.profiles
        WHERE id = v_caller_id;

        IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader') THEN
            RAISE EXCEPTION 'Unauthorized: Only Super Administrators and Leaders can delete student accounts.';
        END IF;
    ELSE
        -- If auth.uid() is NULL, only allow if invoked directly via internal service_role
        IF current_user NOT IN ('service_role', 'postgres') THEN
            RAISE EXCEPTION 'Authentication required: Anonymous callers cannot delete accounts.';
        END IF;
        v_caller_role := 'service_role';
    END IF;

    -- B. Resolve target profile UUID and verify target role
    BEGIN
        v_target_user_id := v_clean_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_target_user_id := NULL;
    END;

    IF v_target_user_id IS NOT NULL THEN
        SELECT id, role::text INTO v_target_user_id, v_target_role
        FROM public.profiles
        WHERE id = v_target_user_id
        LIMIT 1;
    ELSE
        SELECT id, role::text INTO v_target_user_id, v_target_role
        FROM public.profiles
        WHERE university_code = v_clean_id
           OR LOWER(email) = LOWER(v_clean_id)
           OR national_id = v_clean_id
           OR phone_number = v_clean_id
        LIMIT 1;
    END IF;

    -- C. Target Role Guard: Absolutely forbid deleting administrators, coordinators, or doctors
    IF v_target_role IS NOT NULL AND v_target_role <> 'student' THEN
        RAISE EXCEPTION 'Forbidden: Account % has role "%" and cannot be deleted via student deletion RPC.', v_clean_id, v_target_role;
    END IF;

    -- D. Cascade delete all student-associated records across all tables
    IF v_target_user_id IS NOT NULL THEN
        -- 1. Quizzes & answers
        DELETE FROM public.quiz_answers
        WHERE attempt_id IN (SELECT id FROM public.quiz_attempts WHERE student_id = v_target_user_id);
        DELETE FROM public.quiz_attempts WHERE student_id = v_target_user_id;

        -- 2. Attendance & presence
        DELETE FROM public.attendance WHERE student_id = v_target_user_id;
        DELETE FROM public.user_presence WHERE user_id = v_target_user_id;
        DELETE FROM public.user_app_versions WHERE user_id = v_target_user_id;

        -- 3. Roster entries, preferences & requests
        DELETE FROM public.roster_entries WHERE student_id = v_target_user_id;
        DELETE FROM public.roster_preferences WHERE student_id = v_target_user_id;
        DELETE FROM public.shift_requests WHERE student_id = v_target_user_id;

        -- 4. Notifications & push subscriptions
        DELETE FROM public.notifications WHERE user_id = v_target_user_id;
        DELETE FROM public.push_subscriptions WHERE user_id = v_target_user_id;

        -- 5. Cases & clinical handovers
        DELETE FROM public.case_handovers WHERE from_student_id = v_target_user_id OR to_student_id = v_target_user_id;
        DELETE FROM public.cases WHERE current_student_id = v_target_user_id;

        -- 6. Evaluations, disciplinary actions, confirmation requests
        DELETE FROM public.evaluations WHERE student_id = v_target_user_id;
        DELETE FROM public.disciplinary_actions WHERE student_id = v_target_user_id;
        DELETE FROM public.confirmation_requests WHERE target_student_id = v_target_user_id OR sender_id = v_target_user_id;

        -- 7. Community contributions
        DELETE FROM public.community_comments WHERE author_id = v_target_user_id;
        DELETE FROM public.community_posts WHERE author_id = v_target_user_id;

        -- 8. Nullify foreign keys referencing student
        UPDATE public.profiles SET reviewed_by = NULL WHERE reviewed_by = v_target_user_id::text;
        UPDATE public.roster_entries SET approved_by = NULL WHERE approved_by = v_target_user_id;
        UPDATE public.disciplinary_actions SET approved_by = NULL WHERE approved_by = v_target_user_id;
        UPDATE public.community_posts SET featured_by = NULL WHERE featured_by = v_target_user_id;
        UPDATE public.department_supervisors SET assigned_by = NULL WHERE assigned_by = v_target_user_id;
        UPDATE public.department_supervisors SET approved_by = NULL WHERE approved_by = v_target_user_id;

        -- 9. Delete profile row
        DELETE FROM public.profiles WHERE id = v_target_user_id;

        -- 10. Purge from auth.users
        BEGIN
            DELETE FROM auth.users WHERE id = v_target_user_id;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;

        -- 11. Audit log
        INSERT INTO public.audit_logs (user_id, action_type, entity_name, entity_id, old_values)
        VALUES (
            v_caller_id,
            'DELETE_STUDENT',
            'profiles',
            v_target_user_id::text,
            jsonb_build_object('clean_identifier', v_clean_id, 'target_role', v_target_role)
        );
    ELSE
        -- If no UUID resolved, try purge from profiles table by code/email
        DELETE FROM public.profiles
        WHERE (university_code = v_clean_id OR LOWER(email) = LOWER(v_clean_id))
          AND role = 'student';
    END IF;

    RETURN true;
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- 4. Replace delete_student_account(UUID) wrapper
CREATE OR REPLACE FUNCTION public.delete_student_account(p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    RETURN public.delete_student_account(p_student_id::TEXT);
END;
$$;
