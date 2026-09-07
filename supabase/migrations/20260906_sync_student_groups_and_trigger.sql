-- ==============================================================================
-- MIGRATION: Auto-sync student_group name and trigger protection
-- Date: 2026-09-06
-- File: 20260906_sync_student_groups_and_trigger.sql
-- ==============================================================================

-- 1. Sync any existing student profiles with their dynamic group name
UPDATE public.profiles p
SET student_group = sg.name
FROM public.student_groups sg
WHERE p.student_group_id = sg.id
  AND p.role = 'student';

-- 2. Update assign_student_to_group RPC to write both student_group_id and student_group
CREATE OR REPLACE FUNCTION public.assign_student_to_group(
    p_student_id UUID,
    p_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_group RECORD;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient permissions to assign students.';
    END IF;

    SELECT * INTO v_group FROM public.student_groups WHERE id = p_group_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target group not found.';
    END IF;

    UPDATE public.profiles
    SET student_group_id = p_group_id,
        student_group = v_group.name,
        updated_at = NOW()
    WHERE id = p_student_id AND role = 'student';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student not found.';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'group_id', p_group_id,
        'group_name', v_group.name
    );
END;
$$;

-- 3. Update remove_student_from_group RPC to clear both fields
CREATE OR REPLACE FUNCTION public.remove_student_from_group(
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'leader') THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient permissions to remove students.';
    END IF;

    UPDATE public.profiles
    SET student_group_id = NULL,
        student_group = NULL,
        updated_at = NOW()
    WHERE id = p_student_id AND role = 'student';

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 4. Database trigger: Automatically keep student_group string synced with student_group_id
CREATE OR REPLACE FUNCTION public.trg_auto_sync_student_group_name()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.student_group_id IS NOT NULL THEN
        SELECT name INTO NEW.student_group
        FROM public.student_groups
        WHERE id = NEW.student_group_id;
    ELSE
        NEW.student_group := NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_student_group_name ON public.profiles;
CREATE TRIGGER trg_sync_student_group_name
    BEFORE INSERT OR UPDATE OF student_group_id ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_auto_sync_student_group_name();
