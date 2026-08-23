-- ============================================================
-- MIGRATION: Add submitted_at and shift_type to roster_preferences
-- Date: 2026-08-23
-- ============================================================

-- 1. Add submitted_at timestamp column if not present
ALTER TABLE public.roster_preferences
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS shift_type TEXT;

-- 2. Ensure preference_type constraint allows standard shift types and legacy options
ALTER TABLE public.roster_preferences 
  DROP CONSTRAINT IF EXISTS roster_preferences_preference_type_check;

ALTER TABLE public.roster_preferences 
  ADD CONSTRAINT roster_preferences_preference_type_check 
  CHECK (preference_type IN ('A', 'B', 'M', 'L', 'N', 'morning', 'long', 'night'));

-- 3. Reload schema cache for PostgREST
NOTIFY pgrst, 'reload schema';
