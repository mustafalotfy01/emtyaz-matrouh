-- ==============================================================================
-- Migration: Fix Knowledge & Study Files Permissions and RLS for Admins & Leaders
-- Date: 2026-08-27
-- Description:
--   1. Grant full management permissions for knowledge_categories to super_admin, leader, evaluating_doctor.
--   2. Grant full management (INSERT, UPDATE, DELETE) for knowledge_articles to super_admin, leader, evaluating_doctor, and article author.
--   3. Ensure public/authenticated access to categories and published articles.
-- ==============================================================================

-- 1. Enable RLS on all knowledge tables
ALTER TABLE IF EXISTS public.knowledge_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.knowledge_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.knowledge_reading_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.knowledge_bookmarks ENABLE ROW LEVEL SECURITY;

-- 2. Categories Policies
DROP POLICY IF EXISTS "categories_read_policy" ON public.knowledge_categories;
DROP POLICY IF EXISTS "Public categories read" ON public.knowledge_categories;
DROP POLICY IF EXISTS "categories_admin_manage_policy" ON public.knowledge_categories;

CREATE POLICY "categories_read_policy" ON public.knowledge_categories
    FOR SELECT USING (
        is_active = true 
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "categories_admin_manage_policy" ON public.knowledge_categories
    FOR ALL USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

-- 3. Articles & PDF Files Policies
DROP POLICY IF EXISTS "knowledge_articles_read" ON public.knowledge_articles;
DROP POLICY IF EXISTS "knowledge_articles_manage" ON public.knowledge_articles;

CREATE POLICY "knowledge_articles_read" ON public.knowledge_articles
    FOR SELECT USING (
        is_published = true 
        OR author_id = auth.uid() 
        OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
    );

CREATE POLICY "knowledge_articles_manage" ON public.knowledge_articles
    FOR ALL USING (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
        OR author_id = auth.uid()
    )
    WITH CHECK (
        public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor')
        OR author_id = auth.uid()
    );

-- 4. Reading Progress & Bookmarks Policies
DROP POLICY IF EXISTS "reading_progress_user_policy" ON public.knowledge_reading_progress;
CREATE POLICY "reading_progress_user_policy" ON public.knowledge_reading_progress
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "bookmarks_user_policy" ON public.knowledge_bookmarks;
CREATE POLICY "bookmarks_user_policy" ON public.knowledge_bookmarks
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 5. Grant Permissions to all roles
GRANT ALL ON public.knowledge_categories TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.knowledge_articles TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.knowledge_reading_progress TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.knowledge_bookmarks TO postgres, anon, authenticated, service_role;
