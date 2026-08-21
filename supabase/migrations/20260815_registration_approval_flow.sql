-- ========================================================
-- PROJECT: إمتياز مطروح (Nurse Matrouh)
-- Migration: Registration Status, Approvals & Audit Triggers
-- Date: 2026-08-15
-- ========================================================

-- 1. Create Enum for registration status if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'registration_status') THEN
    CREATE TYPE registration_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
  END IF;
END $$;

-- 2. Update profiles table to add registration_status and reviewer info
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS registration_status registration_status DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- 3. Update existing profiles default status
UPDATE public.profiles 
SET registration_status = 'approved' 
WHERE registration_status IS NULL OR role = 'super_admin';

-- 4. Function & Trigger for Student Registration Notifications
CREATE OR REPLACE FUNCTION public.handle_registration_status_change()
RETURNS trigger AS $$
BEGIN
  -- New registration -> Notify Leader & Admin
  IF (TG_OP = 'INSERT' AND NEW.registration_status = 'pending') THEN
    INSERT INTO public.notifications (user_id, title, message, type)
    SELECT id, 'طلب تسجيل جديد 📝', 'تم استلام طلب تسجيل جديد من الطالب: ' || NEW.full_name, 'registration'
    FROM public.profiles
    WHERE role IN ('super_admin', 'leader');

    -- Notify Student
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (NEW.id, 'تم استلام طلب التسجيل ⏳', 'تم استلام طلب التسجيل الخاص بك وجارٍ مراجعته من قبل المنسق.', 'registration');
  END IF;

  -- Registration Status Update Notification & Audit
  IF (TG_OP = 'UPDATE' AND OLD.registration_status IS DISTINCT FROM NEW.registration_status) THEN
    IF NEW.registration_status = 'approved' THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (NEW.id, 'تم اعتماد الحساب 🎉', 'تم اعتماد حسابك بنجاح. يمكنك الان الاستفادة من جميع خدمات التطبيق وتسجيل الشيفتات.', 'registration');
    ELSIF NEW.registration_status = 'rejected' THEN
      INSERT INTO public.notifications (user_id, title, message, type)
      VALUES (NEW.id, 'لم يتم اعتماد طلب التسجيل ⚠️', 'طلب التسجيل غير معتمد. السبب: ' || COALESCE(NEW.rejection_reason, 'لم يحدد سبب'), 'registration');
    END IF;

    -- Audit Log entry
    INSERT INTO public.audit_logs (user_id, action_type, entity_name, entity_id, new_values)
    VALUES (
      NEW.reviewed_by,
      'REGISTRATION_REVIEW',
      'profiles',
      NEW.id::text,
      jsonb_build_object(
        'student_id', NEW.id,
        'student_name', NEW.full_name,
        'action', NEW.registration_status::text,
        'reason', NEW.rejection_reason,
        'timestamp', NOW()
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to profiles
DROP TRIGGER IF EXISTS on_registration_status_change ON public.profiles;
CREATE TRIGGER on_registration_status_change
  AFTER INSERT OR UPDATE OF registration_status ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_registration_status_change();
