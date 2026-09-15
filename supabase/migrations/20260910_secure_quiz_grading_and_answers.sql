-- ==============================================================================
-- MIGRATION: Secure Quiz Answer Keys, Options & Server-Side Grading
-- Date: 2026-09-10
-- File: 20260910_secure_quiz_grading_and_answers.sql
-- Reason: Fix Critical Security Vulnerability (Item 7):
--   1. Prevent client-side answer key leakage (is_correct in quiz_options,
--      correct_option_index and explanation in quiz_questions).
--   2. Restrict direct SELECT on quiz_options and quiz_questions to staff (super_admin,
--      leader, evaluating_doctor) and service_role.
--   3. Deliver sanitized quiz questions to students via get_active_quizzes RPC,
--      masking correct_option_index as -1 and explanation as NULL before submission.
--   4. Implement server-side grading via submit_quiz_attempt RPC to prevent
--      fabricated student scores and client-side grade tampering.
--   5. Restrict direct INSERT on quiz_attempts and quiz_answers to staff/service_role.
-- ==============================================================================

-- 1. Secure quiz_options: Only staff and service_role can select is_correct
DROP POLICY IF EXISTS "quiz_options_select" ON public.quiz_options;
CREATE POLICY "quiz_options_select" ON public.quiz_options
    FOR SELECT
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
        OR current_user IN ('service_role', 'postgres')
    );

-- 2. Secure quiz_questions: Only staff and service_role can select directly from quiz_questions table
DROP POLICY IF EXISTS "quiz_questions_select" ON public.quiz_questions;
CREATE POLICY "quiz_questions_select" ON public.quiz_questions
    FOR SELECT
    TO authenticated, service_role
    USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
        OR current_user IN ('service_role', 'postgres')
    );

-- 3. Secure quiz_attempts and quiz_answers direct inserts
DROP POLICY IF EXISTS "quiz_attempts_insert" ON public.quiz_attempts;
CREATE POLICY "quiz_attempts_insert" ON public.quiz_attempts
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR current_user IN ('service_role', 'postgres')
    );

DROP POLICY IF EXISTS "quiz_answers_insert" ON public.quiz_answers;
CREATE POLICY "quiz_answers_insert" ON public.quiz_answers
    FOR INSERT
    TO authenticated, service_role
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader')
        OR current_user IN ('service_role', 'postgres')
    );

-- 4. RPC: get_active_quizzes()
-- Safely delivers published quizzes. For students, masks correct_option_index and explanation.
CREATE OR REPLACE FUNCTION public.get_active_quizzes()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
  v_is_staff BOOLEAN;
  v_result JSONB;
BEGIN
  -- Determine caller role
  v_caller_role := public.get_auth_role();
  v_is_staff := (v_caller_role IN ('super_admin', 'leader', 'evaluating_doctor') OR current_user IN ('service_role', 'postgres'));

  SELECT jsonb_agg(quiz_row)
  INTO v_result
  FROM (
    SELECT 
      q.id,
      q.title,
      q.description,
      q.department_id,
      q.time_limit_minutes,
      q.passing_score,
      q.is_active,
      q.created_at,
      jsonb_build_object('name_ar', COALESCE(d.name_ar, 'قسم التمريض العام')) AS departments,
      COALESCE(
        (
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', qq.id,
              'quiz_id', qq.quiz_id,
              'question_text', qq.question_text,
              'type', qq.type::text,
              'options', qq.options,
              'duration_seconds', qq.duration_seconds,
              'order_index', qq.order_index,
              'correct_option_index', CASE WHEN v_is_staff THEN qq.correct_option_index ELSE -1 END,
              'explanation', CASE WHEN v_is_staff THEN qq.explanation ELSE NULL END
            ) ORDER BY qq.order_index ASC, qq.id ASC
          )
          FROM public.quiz_questions qq
          WHERE qq.quiz_id = q.id
        ),
        '[]'::jsonb
      ) AS quiz_questions
    FROM public.quizzes q
    LEFT JOIN public.departments d ON d.id = q.department_id
    WHERE q.is_active = true OR v_is_staff
    ORDER BY q.created_at DESC
  ) quiz_row;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 5. RPC: submit_quiz_attempt()
-- Authoritative server-side grading and recording of quiz attempt and answers.
CREATE OR REPLACE FUNCTION public.submit_quiz_attempt(
  p_quiz_id UUID,
  p_answers JSONB,
  p_completion_time_seconds INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_id UUID;
  v_quiz RECORD;
  v_question RECORD;
  v_total_questions INT := 0;
  v_correct_count INT := 0;
  v_incorrect_count INT := 0;
  v_unanswered_count INT := 0;
  v_score_percentage DOUBLE PRECISION := 0.0;
  v_passed BOOLEAN := false;
  v_attempt_id UUID;
  v_selected_idx INT;
  v_is_correct BOOLEAN;
  v_feedback JSONB := '[]'::jsonb;
  v_ans_elem JSONB;
BEGIN
  -- A. Enforce Caller Authentication
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    IF current_user NOT IN ('service_role', 'postgres') THEN
      RAISE EXCEPTION 'Authentication required: Anonymous callers cannot submit quiz attempts.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- B. Verify Quiz Existence & State
  SELECT id, title, passing_score, is_active
  INTO v_quiz
  FROM public.quizzes
  WHERE id = p_quiz_id;

  IF v_quiz IS NULL THEN
    RAISE EXCEPTION 'Quiz not found' USING ERRCODE = '22023';
  END IF;

  IF NOT v_quiz.is_active THEN
    RAISE EXCEPTION 'Quiz is currently inactive' USING ERRCODE = '22023';
  END IF;

  -- C. Grade each question server-side against authentic quiz_questions
  FOR v_question IN
    SELECT id, correct_option_index, explanation, order_index
    FROM public.quiz_questions
    WHERE quiz_id = p_quiz_id
    ORDER BY order_index ASC, id ASC
  LOOP
    v_total_questions := v_total_questions + 1;
    v_selected_idx := NULL;
    v_is_correct := false;

    -- Locate student's answer for this question from p_answers
    -- p_answers can be:
    -- 1) Array of objects: [{"question_id": "...", "selected_option_index": 2}]
    -- 2) Map of question_id -> selected_option_index or order_index -> selected_option_index
    IF jsonb_typeof(p_answers) = 'array' THEN
      FOR v_ans_elem IN SELECT * FROM jsonb_array_elements(p_answers)
      LOOP
        IF (v_ans_elem->>'question_id' = v_question.id::text) 
           OR (v_ans_elem->>'order_index' = v_question.order_index::text) THEN
          IF v_ans_elem->>'selected_option_index' IS NOT NULL THEN
            v_selected_idx := (v_ans_elem->>'selected_option_index')::int;
          END IF;
          EXIT;
        END IF;
      END LOOP;
    ELSIF jsonb_typeof(p_answers) = 'object' THEN
      IF p_answers ? v_question.id::text THEN
        v_selected_idx := (p_answers->>v_question.id::text)::int;
      ELSIF p_answers ? v_question.order_index::text THEN
        v_selected_idx := (p_answers->>v_question.order_index::text)::int;
      END IF;
    END IF;

    -- Evaluate correctness
    IF v_selected_idx IS NULL OR v_selected_idx < 0 THEN
      v_unanswered_count := v_unanswered_count + 1;
      v_is_correct := false;
    ELSIF v_selected_idx = v_question.correct_option_index THEN
      v_correct_count := v_correct_count + 1;
      v_is_correct := true;
    ELSE
      v_incorrect_count := v_incorrect_count + 1;
      v_is_correct := false;
    END IF;

    -- Append feedback item (unlocked post-submission)
    v_feedback := v_feedback || jsonb_build_object(
      'question_id', v_question.id,
      'selected_option_index', v_selected_idx,
      'correct_option_index', v_question.correct_option_index,
      'is_correct', v_is_correct,
      'explanation', v_question.explanation
    );
  END LOOP;

  IF v_total_questions > 0 THEN
    v_score_percentage := ROUND(((v_correct_count::numeric / v_total_questions::numeric) * 100.0), 2);
  ELSE
    v_score_percentage := 0.0;
  END IF;

  v_passed := (v_score_percentage >= v_quiz.passing_score);

  -- D. Insert Authoritative Attempt Record
  INSERT INTO public.quiz_attempts (
    quiz_id,
    student_id,
    score_percentage,
    passed,
    total_questions,
    correct_count,
    incorrect_count,
    unanswered_count,
    completion_time_seconds,
    completed_at
  ) VALUES (
    p_quiz_id,
    v_caller_id,
    v_score_percentage,
    v_passed,
    v_total_questions,
    v_correct_count,
    v_incorrect_count,
    v_unanswered_count,
    p_completion_time_seconds,
    NOW()
  ) RETURNING id INTO v_attempt_id;

  -- E. Insert Individual Answers
  FOR v_ans_elem IN SELECT * FROM jsonb_array_elements(v_feedback)
  LOOP
    INSERT INTO public.quiz_answers (
      attempt_id,
      question_id,
      selected_option_index,
      is_correct
    ) VALUES (
      v_attempt_id,
      (v_ans_elem->>'question_id')::uuid,
      (v_ans_elem->>'selected_option_index')::int,
      (v_ans_elem->>'is_correct')::boolean
    );
  END LOOP;

  -- F. Return verified authoritative result with post-submission explanations
  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', v_attempt_id,
    'quiz_id', p_quiz_id,
    'student_id', v_caller_id,
    'score_percentage', v_score_percentage,
    'passed', v_passed,
    'total_questions', v_total_questions,
    'correct_count', v_correct_count,
    'incorrect_count', v_incorrect_count,
    'unanswered_count', v_unanswered_count,
    'completion_time_seconds', p_completion_time_seconds,
    'questions_feedback', v_feedback
  );
END;
$$;

-- 6. Grant execute on RPCs
REVOKE ALL ON FUNCTION public.get_active_quizzes() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_active_quizzes() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_active_quizzes() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_quiz_attempt(UUID, JSONB, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_quiz_attempt(UUID, JSONB, INT) FROM anon;
GRANT EXECUTE ON FUNCTION public.submit_quiz_attempt(UUID, JSONB, INT) TO authenticated, service_role;
