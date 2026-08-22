-- ==============================================================================
-- إمتياز مطروح (Nurse Matrouh) — الإصلاح الشامل والجذري لحذف حساب الطالب نهائياً
-- التاريخ: 2026-08-22
-- الملف: 20260822_fix_student_deletion_cascade.sql
-- ==============================================================================

-- 1. إسقاط الدوال القديمة إن وجدت بأي معاملات
DROP FUNCTION IF EXISTS public.delete_student_account(UUID);
DROP FUNCTION IF EXISTS public.delete_student_account(TEXT);

-- 2. دالة RPC فائقة الحصانة لحذف حساب الطالب نهائياً مع كافة بياناته المرتبطة (Cascade Delete)
CREATE OR REPLACE FUNCTION public.delete_student_account(p_student_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := NULL;
    v_clean_id TEXT;
BEGIN
    v_clean_id := TRIM(p_student_id);

    -- 1. محاولة استخراج معرف UUID الخاص بالطالب سواء تم تمرير UUID أو الكود الجامعي أو البريد الإلكتروني
    BEGIN
        v_user_id := v_clean_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;

    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id
        FROM public.profiles
        WHERE university_code = v_clean_id 
           OR LOWER(email) = LOWER(v_clean_id)
           OR national_id = v_clean_id
           OR phone_number = v_clean_id
        LIMIT 1;
    END IF;

    -- 2. حذف كافة السجلات التابعة للطالب في كافة الجداول
    IF v_user_id IS NOT NULL THEN
        -- الاختبارات والإجابات
        DELETE FROM public.quiz_answers 
        WHERE attempt_id IN (SELECT id FROM public.quiz_attempts WHERE student_id = v_user_id);
        
        DELETE FROM public.quiz_attempts WHERE student_id = v_user_id;
        
        -- الحضور والانصراف
        DELETE FROM public.attendance WHERE student_id = v_user_id;
        
        -- جدول النبطشيات والتفضيلات والطلبات
        DELETE FROM public.roster_entries WHERE student_id = v_user_id;
        DELETE FROM public.roster_preferences WHERE student_id = v_user_id;
        DELETE FROM public.shift_requests WHERE student_id = v_user_id;
        
        -- الإشعارات
        DELETE FROM public.notifications WHERE user_id = v_user_id;
        
        -- تسليم الحالات والحالات السريرية
        DELETE FROM public.case_handovers WHERE from_student_id = v_user_id OR to_student_id = v_user_id;
        DELETE FROM public.cases WHERE current_student_id = v_user_id;
        
        -- التقييمات والجزاءات
        DELETE FROM public.evaluations WHERE student_id = v_user_id;
        DELETE FROM public.disciplinary_actions WHERE student_id = v_user_id;
        
        -- طلبات البصمة الفورية والتأكيد
        DELETE FROM public.confirmation_requests WHERE target_student_id = v_user_id OR sender_id = v_user_id;
        
        -- المجتمع والمنشورات والتعليقات
        DELETE FROM public.community_comments WHERE author_id = v_user_id;
        DELETE FROM public.community_posts WHERE author_id = v_user_id;
        
        -- سجلات الرقابة
        DELETE FROM public.audit_logs WHERE user_id = v_user_id;

        -- تصفير المفاتيح الأجنبية التي قد تشير إلى الطالب لمنع أي قيد Foreign Key
        UPDATE public.profiles SET reviewed_by = NULL WHERE reviewed_by = v_user_id::text;
        UPDATE public.roster_entries SET approved_by = NULL WHERE approved_by = v_user_id;
        UPDATE public.disciplinary_actions SET approved_by = NULL WHERE approved_by = v_user_id;
        UPDATE public.community_posts SET featured_by = NULL WHERE featured_by = v_user_id;
        UPDATE public.department_supervisors SET assigned_by = NULL WHERE assigned_by = v_user_id;
        UPDATE public.department_supervisors SET approved_by = NULL WHERE approved_by = v_user_id;

        -- حذف الملف الشخصي من جدول profiles
        DELETE FROM public.profiles WHERE id = v_user_id;

        -- حذف المستخدم من auth.users لمنع أي تسجيل دخول مستقبلي
        BEGIN
            DELETE FROM auth.users WHERE id = v_user_id;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    ELSE
        -- إذا لم يكن له UUID، نحذفه مباشرة عبر الكود الجامعي أو البريد من profiles
        DELETE FROM public.profiles 
        WHERE university_code = v_clean_id 
           OR LOWER(email) = LOWER(v_clean_id);
    END IF;

    RETURN true;
EXCEPTION WHEN OTHERS THEN
    RETURN false;
END;
$$;

-- 3. دالة بديلة تدعم تمرير UUID مباشرة
CREATE OR REPLACE FUNCTION public.delete_student_account(p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.delete_student_account(p_student_id::TEXT);
END;
$$;

-- 4. التأكد من سياسات الحذف لجميع الجداول
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_delete_policy" ON public.profiles;
CREATE POLICY "profiles_delete_policy" ON public.profiles FOR DELETE USING (true);

ALTER TABLE public.roster_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "roster_entries_delete_policy" ON public.roster_entries;
CREATE POLICY "roster_entries_delete_policy" ON public.roster_entries FOR DELETE USING (true);

ALTER TABLE public.roster_preferences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "roster_preferences_delete_policy" ON public.roster_preferences;
CREATE POLICY "roster_preferences_delete_policy" ON public.roster_preferences FOR DELETE USING (true);

ALTER TABLE public.shift_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "shift_requests_delete_policy" ON public.shift_requests;
CREATE POLICY "shift_requests_delete_policy" ON public.shift_requests FOR DELETE USING (true);

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "attendance_delete_policy" ON public.attendance;
CREATE POLICY "attendance_delete_policy" ON public.attendance FOR DELETE USING (true);

ALTER TABLE public.evaluations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "evaluations_delete_policy" ON public.evaluations;
CREATE POLICY "evaluations_delete_policy" ON public.evaluations FOR DELETE USING (true);

ALTER TABLE public.disciplinary_actions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "disciplinary_actions_delete_policy" ON public.disciplinary_actions;
CREATE POLICY "disciplinary_actions_delete_policy" ON public.disciplinary_actions FOR DELETE USING (true);

ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cases_delete_policy" ON public.cases;
CREATE POLICY "cases_delete_policy" ON public.cases FOR DELETE USING (true);

ALTER TABLE public.case_handovers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "case_handovers_delete_policy" ON public.case_handovers;
CREATE POLICY "case_handovers_delete_policy" ON public.case_handovers FOR DELETE USING (true);

ALTER TABLE public.confirmation_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "confirmation_requests_delete_policy" ON public.confirmation_requests;
CREATE POLICY "confirmation_requests_delete_policy" ON public.confirmation_requests FOR DELETE USING (true);

ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "community_comments_delete_policy" ON public.community_comments;
CREATE POLICY "community_comments_delete_policy" ON public.community_comments FOR DELETE USING (true);

ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "community_posts_delete_policy" ON public.community_posts;
CREATE POLICY "community_posts_delete_policy" ON public.community_posts FOR DELETE USING (true);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notifications_delete_policy" ON public.notifications;
CREATE POLICY "notifications_delete_policy" ON public.notifications FOR DELETE USING (true);

ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "quiz_attempts_delete_policy" ON public.quiz_attempts;
CREATE POLICY "quiz_attempts_delete_policy" ON public.quiz_attempts FOR DELETE USING (true);

ALTER TABLE public.quiz_answers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "quiz_answers_delete_policy" ON public.quiz_answers;
CREATE POLICY "quiz_answers_delete_policy" ON public.quiz_answers FOR DELETE USING (true);

-- 5. منح صلاحيات التنفيذ للدوال
GRANT EXECUTE ON FUNCTION public.delete_student_account(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_student_account(UUID) TO anon, authenticated, service_role;
