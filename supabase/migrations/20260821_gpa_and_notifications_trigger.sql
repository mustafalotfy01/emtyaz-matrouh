-- ============================================================
-- MIGRATION: Add GPA to Profiles & Server-Side Notification Trigger
-- Date: 2026-08-21
-- ============================================================

-- 1. Add gpa column to profiles and make national_id nullable
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS gpa NUMERIC(3,2);

ALTER TABLE public.profiles
  ALTER COLUMN national_id DROP NOT NULL;

-- 2. Add metadata column to notifications if not exists
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS metadata JSONB;

-- 3. Create server-side notification trigger for new student registrations
CREATE OR REPLACE FUNCTION public.notify_leaders_on_student_registration()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_leader RECORD;
BEGIN
  IF NEW.role = 'student' AND (NEW.registration_status = 'pending' OR NEW.is_approved = false) THEN
    FOR v_leader IN SELECT id FROM public.profiles WHERE role IN ('leader', 'super_admin') LOOP
      INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        metadata,
        is_read,
        created_at
      ) VALUES (
        v_leader.id,
        'طالب جديد يحتاج للمراجعة',
        'قام الطالب ' || NEW.full_name || ' بالتسجيل في المنصة (GPA: ' || COALESCE(NEW.gpa::text, 'غير محدد') || ') وينتظر اعتمادك.',
        'NEW_STUDENT_REGISTRATION',
        jsonb_build_object(
          'student_id', NEW.id,
          'student_name', NEW.full_name,
          'university_code', NEW.university_code,
          'gpa', NEW.gpa,
          'student_group', NEW.student_group
        ),
        false,
        NOW()
      );
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_leaders_on_student_registration ON public.profiles;
CREATE TRIGGER trg_notify_leaders_on_student_registration
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.notify_leaders_on_student_registration();
