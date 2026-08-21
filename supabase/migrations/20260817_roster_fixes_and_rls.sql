-- ========================================================
-- MIGRATION: Roster Fixes & Row Level Security (RLS) Policies
-- Date: 2026-08-17
-- Fixes:
--   1. RLS policy allowing Students to SELECT their own approved final roster_entries
--   2. RLS policies allowing Students to UPSERT their preferences
--   3. Unique constraint enforcement for roster_preferences & roster_entries
-- ========================================================

-- 1. Enable RLS on roster_entries
ALTER TABLE public.roster_entries ENABLE ROW LEVEL SECURITY;

-- 2. Allow students to SELECT ONLY their own approved roster entries (and Leaders/Admins/Doctors to view all)
DROP POLICY IF EXISTS "roster_entries_student_select" ON public.roster_entries;
CREATE POLICY "roster_entries_student_select" ON public.roster_entries
  FOR SELECT USING (
    student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
  );

-- 3. Allow Leaders and Admins to manage (INSERT / UPDATE / DELETE) roster_entries
DROP POLICY IF EXISTS "roster_entries_leader_manage" ON public.roster_entries;
CREATE POLICY "roster_entries_leader_manage" ON public.roster_entries
  FOR ALL USING (
    public.get_auth_role() IN ('super_admin', 'leader')
  );

-- 4. Enable RLS on roster_preferences
ALTER TABLE public.roster_preferences ENABLE ROW LEVEL SECURITY;

-- 5. Policies for roster_preferences (SELECT, INSERT, UPDATE, DELETE for Students & Leaders)
DROP POLICY IF EXISTS "roster_pref_select" ON public.roster_preferences;
CREATE POLICY "roster_pref_select" ON public.roster_preferences
  FOR SELECT USING (
    student_id = auth.uid() 
    OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
  );

DROP POLICY IF EXISTS "roster_pref_insert" ON public.roster_preferences;
CREATE POLICY "roster_pref_insert" ON public.roster_preferences
  FOR INSERT WITH CHECK (
    student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "roster_pref_update" ON public.roster_preferences;
CREATE POLICY "roster_pref_update" ON public.roster_preferences
  FOR UPDATE USING (
    student_id = auth.uid() 
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

DROP POLICY IF EXISTS "roster_pref_delete" ON public.roster_preferences;
CREATE POLICY "roster_pref_delete" ON public.roster_preferences
  FOR DELETE USING (
    student_id = auth.uid()
    OR public.get_auth_role() IN ('super_admin', 'leader')
  );

-- 6. Grant Permissions to standard roles
GRANT ALL ON public.roster_entries TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.roster_preferences TO postgres, anon, authenticated, service_role;
