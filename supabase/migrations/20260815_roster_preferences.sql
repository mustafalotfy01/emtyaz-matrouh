-- ============================================================
-- MIGRATION: Roster Preferences System & Student Groups
-- Date: 2026-08-15
-- ============================================================

-- 1. Add student_group to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS student_group TEXT
    CHECK (student_group IN ('A', 'B'));

-- 2. Add roster workflow status fields to rosters table
ALTER TABLE public.rosters
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','open','student_submission','leader_review','assignment','ready_for_approval','published','locked')),
  ADD COLUMN IF NOT EXISTS opened_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS submission_deadline TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS published_by UUID REFERENCES public.profiles(id);

-- 3. Create roster_preferences table (student date preferences)
CREATE TABLE IF NOT EXISTS public.roster_preferences (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  roster_id       UUID NOT NULL REFERENCES public.rosters(id) ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  preference_date DATE NOT NULL,
  preference_type TEXT NOT NULL CHECK (preference_type IN ('A', 'B')),
  status          TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'locked')),
  submitted_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_student_roster_date_pref UNIQUE (roster_id, student_id, preference_date)
);

CREATE INDEX IF NOT EXISTS idx_roster_prefs_student ON public.roster_preferences(student_id, roster_id);
CREATE INDEX IF NOT EXISTS idx_roster_prefs_roster ON public.roster_preferences(roster_id);

-- 4. Alter roster_entries (final roster)
ALTER TABLE public.roster_entries
  ADD COLUMN IF NOT EXISTS source_preference_id UUID REFERENCES public.roster_preferences(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS preference_type TEXT CHECK (preference_type IN ('A', 'B')),
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'approved', 'published')),
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS final_shift_type TEXT
    CHECK (final_shift_type IN ('morning', 'evening', 'long', 'night'));

-- 5. Validation and RPC Functions
CREATE OR REPLACE FUNCTION public.validate_roster_preferences(
  p_student_id UUID,
  p_roster_id  UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_a_count      INT;
  v_b_count      INT;
  v_overlap      INT;
  v_group        TEXT;
  v_errors       JSONB := '[]'::JSONB;
BEGIN
  SELECT student_group INTO v_group FROM public.profiles WHERE id = p_student_id;

  SELECT COUNT(*) INTO v_a_count
  FROM public.roster_preferences
  WHERE student_id = p_student_id AND roster_id = p_roster_id AND preference_type = 'A';

  SELECT COUNT(*) INTO v_b_count
  FROM public.roster_preferences
  WHERE student_id = p_student_id AND roster_id = p_roster_id AND preference_type = 'B';

  IF v_a_count != 12 THEN
    v_errors := v_errors || jsonb_build_array(
      jsonb_build_object('code', 'A_COUNT', 'message', 'يجب اختيار 12 تاريخ Option A، الحالي: ' || v_a_count)
    );
  END IF;

  IF v_b_count != 12 THEN
    v_errors := v_errors || jsonb_build_array(
      jsonb_build_object('code', 'B_COUNT', 'message', 'يجب اختيار 12 تاريخ Option B، الحالي: ' || v_b_count)
    );
  END IF;

  IF v_group = 'A' THEN
    SELECT COUNT(*) INTO v_overlap
    FROM public.roster_preferences
    WHERE student_id = p_student_id
      AND roster_id = p_roster_id
      AND EXTRACT(DAY FROM preference_date) > 16;
    IF v_overlap > 0 THEN
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('code', 'GROUP_VIOLATION', 'message', 'المجموعة A: الأيام المسموحة 1-16 فقط')
      );
    END IF;
  ELSIF v_group = 'B' THEN
    SELECT COUNT(*) INTO v_overlap
    FROM public.roster_preferences
    WHERE student_id = p_student_id
      AND roster_id = p_roster_id
      AND EXTRACT(DAY FROM preference_date) < 17;
    IF v_overlap > 0 THEN
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('code', 'GROUP_VIOLATION', 'message', 'المجموعة B: الأيام المسموحة 17 إلى نهاية الشهر')
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'valid', jsonb_array_length(v_errors) = 0,
    'errors', v_errors,
    'a_count', v_a_count,
    'b_count', v_b_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_roster_preferences(
  p_student_id UUID,
  p_roster_id  UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_validation JSONB;
  v_now        TIMESTAMPTZ := NOW();
BEGIN
  v_validation := public.validate_roster_preferences(p_student_id, p_roster_id);

  IF NOT (v_validation->>'valid')::BOOLEAN THEN
    RETURN v_validation;
  END IF;

  UPDATE public.roster_preferences
  SET status = 'submitted', submitted_at = v_now, updated_at = v_now
  WHERE student_id = p_student_id AND roster_id = p_roster_id;

  INSERT INTO public.audit_logs (user_id, action_type, entity_name, entity_id, new_values)
  VALUES (
    p_student_id,
    'preference_submitted',
    'roster_preferences',
    p_roster_id::TEXT,
    jsonb_build_object('student_id', p_student_id, 'roster_id', p_roster_id, 'submitted_at', v_now)
  );

  RETURN jsonb_build_object('valid', true, 'message', 'تم إرسال الاختيارات بنجاح');
END;
$$;

CREATE OR REPLACE FUNCTION public.reopen_roster_preferences(
  p_leader_id  UUID,
  p_student_id UUID,
  p_roster_id  UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.roster_preferences
  SET status = 'draft', submitted_at = NULL, updated_at = NOW()
  WHERE student_id = p_student_id AND roster_id = p_roster_id;

  INSERT INTO public.audit_logs (user_id, action_type, entity_name, entity_id, new_values)
  VALUES (
    p_leader_id,
    'preference_reopened',
    'roster_preferences',
    p_roster_id::TEXT,
    jsonb_build_object('student_id', p_student_id, 'leader_id', p_leader_id)
  );
END;
$$;

-- 6. RLS Policies
ALTER TABLE public.roster_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "roster_pref_student_select" ON public.roster_preferences;
CREATE POLICY "roster_pref_student_select" ON public.roster_preferences
  FOR SELECT USING (student_id = auth.uid() OR public.get_auth_role() IN ('leader', 'super_admin'));

DROP POLICY IF EXISTS "roster_pref_student_insert" ON public.roster_preferences;
CREATE POLICY "roster_pref_student_insert" ON public.roster_preferences
  FOR INSERT WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "roster_pref_student_update" ON public.roster_preferences;
CREATE POLICY "roster_pref_student_update" ON public.roster_preferences
  FOR UPDATE USING (
    (student_id = auth.uid() AND status = 'draft')
    OR public.get_auth_role() IN ('leader', 'super_admin')
  );

DROP POLICY IF EXISTS "roster_pref_student_delete" ON public.roster_preferences;
CREATE POLICY "roster_pref_student_delete" ON public.roster_preferences
  FOR DELETE USING (
    (student_id = auth.uid() AND status = 'draft')
    OR public.get_auth_role() IN ('leader', 'super_admin')
  );
