-- ==============================================================================
-- FIX DISCIPLINARY ACTIONS RLS & DIRECT ACTION APPROVAL POLICIES
-- Date: 2026-08-22
-- ==============================================================================

-- 1. Fix trigger to only prevent evaluating doctors from self-approving, NOT Admins or Leaders
CREATE OR REPLACE FUNCTION public.trg_prevent_doctor_self_approval()
RETURNS TRIGGER AS $$
BEGIN
  -- Only block doctors/creators who are evaluating_doctor from self approving
  IF NEW.status = 'approved' 
     AND NEW.approved_by IS NOT NULL 
     AND NEW.approved_by = NEW.created_by 
     AND (NEW.created_by_role = 'evaluating_doctor' OR NEW.created_by_role = 'doctor') THEN
    RAISE EXCEPTION 'Security Violation: Evaluating Doctors cannot approve their own disciplinary actions.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS check_disciplinary_self_approval ON public.disciplinary_actions;
CREATE TRIGGER check_disciplinary_self_approval
  BEFORE UPDATE OR INSERT ON public.disciplinary_actions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_prevent_doctor_self_approval();

-- 2. Ensure RLS is active and policies allow super_admin, leader and evaluating_doctor
ALTER TABLE public.disciplinary_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Disciplinary actions student select" ON public.disciplinary_actions;
CREATE POLICY "Disciplinary actions student select" ON public.disciplinary_actions
    FOR SELECT USING (
      student_id = auth.uid() 
      OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

DROP POLICY IF EXISTS "Disciplinary actions insert policy" ON public.disciplinary_actions;
DROP POLICY IF EXISTS "Disciplinary actions leader insert" ON public.disciplinary_actions;
CREATE POLICY "Disciplinary actions insert policy" ON public.disciplinary_actions
    FOR INSERT WITH CHECK (
      public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

DROP POLICY IF EXISTS "Disciplinary actions update policy" ON public.disciplinary_actions;
CREATE POLICY "Disciplinary actions update policy" ON public.disciplinary_actions
    FOR UPDATE USING (
      public.get_auth_role() IN ('super_admin', 'leader')
    )
    WITH CHECK (
      public.get_auth_role() IN ('super_admin', 'leader')
    );

DROP POLICY IF EXISTS "Disciplinary actions delete policy" ON public.disciplinary_actions;
CREATE POLICY "Disciplinary actions delete policy" ON public.disciplinary_actions
    FOR DELETE USING (
      public.get_auth_role() = 'super_admin'
    );

-- 3. Stored procedure for direct actions (Guaranteed execution for Admins and Leaders)
CREATE OR REPLACE FUNCTION public.apply_direct_disciplinary_action(
  p_student_id UUID,
  p_department_id UUID,
  p_action_type TEXT,
  p_reason TEXT,
  p_description TEXT,
  p_deduction_value NUMERIC,
  p_deduction_unit TEXT DEFAULT 'points',
  p_severity INT DEFAULT 1,
  p_admin_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_role TEXT;
  v_caller_id UUID;
  v_new_id UUID;
  v_result JSONB;
BEGIN
  v_caller_id := auth.uid();
  v_caller_role := public.get_auth_role();

  IF v_caller_role NOT IN ('super_admin', 'leader') THEN
    RAISE EXCEPTION 'Unauthorized: Only Super Admins and Leaders can apply direct disciplinary actions.';
  END IF;

  INSERT INTO public.disciplinary_actions (
    student_id,
    department_id,
    created_by,
    created_by_role,
    approved_by,
    action_type,
    severity,
    reason,
    description,
    deduction_value,
    deduction_unit,
    status,
    admin_note,
    action_date,
    created_at,
    updated_at
  ) VALUES (
    p_student_id,
    p_department_id,
    v_caller_id,
    v_caller_role,
    v_caller_id,
    p_action_type,
    p_severity,
    p_reason,
    p_description,
    p_deduction_value,
    p_deduction_unit,
    'approved',
    p_admin_note,
    CURRENT_DATE,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_new_id;

  -- Create Notification for the student
  INSERT INTO public.notifications (
    user_id,
    title,
    message,
    type,
    is_read,
    created_at
  ) VALUES (
    p_student_id,
    CASE WHEN p_action_type IN ('bonus_points', 'honor_badge', 'appreciation') THEN 'مكافأة تقديرية جديدة ⭐' ELSE 'إجراء إداري / جزاء ⚠️' END,
    'تم تسجيل إجراء رسمي: ' || p_reason || ' (' || p_deduction_value || ' ' || p_deduction_unit || ')',
    'DISCIPLINARY_UPDATE',
    false,
    NOW()
  );

  SELECT row_to_json(d)::jsonb INTO v_result
  FROM (
    SELECT 
      da.*,
      json_build_object('id', st.id, 'full_name', st.full_name, 'university_code', st.university_code) as student,
      json_build_object('id', cr.id, 'full_name', cr.full_name) as creator,
      json_build_object('id', ap.id, 'full_name', ap.full_name) as approver,
      json_build_object('id', dp.id, 'name_ar', dp.name_ar) as department
    FROM public.disciplinary_actions da
    LEFT JOIN public.profiles st ON st.id = da.student_id
    LEFT JOIN public.profiles cr ON cr.id = da.created_by
    LEFT JOIN public.profiles ap ON ap.id = da.approved_by
    LEFT JOIN public.departments dp ON dp.id = da.department_id
    WHERE da.id = v_new_id
  ) d;

  RETURN v_result;
END;
$$;
