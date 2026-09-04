-- ==============================================================================
-- MIGRATION: Add 'average' (نص ونص) Classification
-- Date: 2026-09-04
-- File: 20260904_add_average_student_classification.sql
-- ==============================================================================

-- 1. ADD 'average' VALUE TO ENUM TYPE IF NOT ALREADY PRESENT
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum
        WHERE enumtypid = 'public.student_classification_type'::regtype
          AND enumlabel = 'average'
    ) THEN
        ALTER TYPE public.student_classification_type ADD VALUE 'average';
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        NULL;
END $$;

-- 2. UPDATE RPC FUNCTION: update_student_classification
CREATE OR REPLACE FUNCTION public.update_student_classification(
    p_student_id UUID,
    p_classification TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_class_val public.student_classification_type;
BEGIN
    SELECT role::text INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role != 'super_admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only Super Admin can modify student classification.';
    END IF;

    IF p_classification NOT IN ('practical_strong', 'theoretical_strong', 'average', 'weak') THEN
        RAISE EXCEPTION 'Invalid classification. Allowed: practical_strong, theoretical_strong, average, weak.';
    END IF;

    v_class_val := p_classification::public.student_classification_type;

    UPDATE public.profiles
    SET student_classification = v_class_val,
        updated_at = NOW()
    WHERE id = p_student_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student with ID % not found.', p_student_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student_id', p_student_id,
        'classification', p_classification
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_student_classification(UUID, TEXT) TO authenticated, service_role;
