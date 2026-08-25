-- ==============================================================================
-- MIGRATION: Clinical Library, Google Drive Backend, Subcategories & Reading System
-- Date: 2026-08-25
-- File: 20260825_clinical_library_google_drive_and_subcategories.sql
-- ==============================================================================

-- 1. KNOWLEDGE CATEGORIES EXTENSION (SUPPORT MAIN & SUBCATEGORIES)
ALTER TABLE public.knowledge_categories
    ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.knowledge_categories(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS order_index INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_kcategories_parent ON public.knowledge_categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_kcategories_active ON public.knowledge_categories(is_active);
CREATE INDEX IF NOT EXISTS idx_kcategories_order ON public.knowledge_categories(order_index ASC);

-- 2. KNOWLEDGE ARTICLES EXTENSION (SUPPORT GOOGLE DRIVE, METADATA & CONTENT TYPES)
ALTER TABLE public.knowledge_articles
    ADD COLUMN IF NOT EXISTS subcategory_id UUID REFERENCES public.knowledge_categories(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS drive_file_id TEXT,
    ADD COLUMN IF NOT EXISTS drive_file_url TEXT,
    ADD COLUMN IF NOT EXISTS file_name TEXT,
    ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT,
    ADD COLUMN IF NOT EXISTS page_count INT,
    ADD COLUMN IF NOT EXISTS author_name TEXT,
    ADD COLUMN IF NOT EXISTS publisher TEXT,
    ADD COLUMN IF NOT EXISTS publication_year INT,
    ADD COLUMN IF NOT EXISTS edition TEXT,
    ADD COLUMN IF NOT EXISTS language TEXT DEFAULT 'العربية',
    ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;

-- Drop old check constraint on content_type and replace with expanded one
DO $$
BEGIN
    ALTER TABLE public.knowledge_articles DROP CONSTRAINT IF EXISTS knowledge_articles_content_type_check;
    ALTER TABLE public.knowledge_articles DROP CONSTRAINT IF EXISTS knowledge_articles_type_check;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.knowledge_articles
    ADD CONSTRAINT knowledge_articles_content_type_check 
    CHECK (content_type IS NULL OR content_type IN (
        'procedure', 'disease', 'medication', 'lesson', 'general', 'scientific_reference', 'pdf', 'text'
    ));

CREATE INDEX IF NOT EXISTS idx_karticles_category ON public.knowledge_articles(category_id);
CREATE INDEX IF NOT EXISTS idx_karticles_subcategory ON public.knowledge_articles(subcategory_id);
CREATE INDEX IF NOT EXISTS idx_karticles_published ON public.knowledge_articles(is_published);
CREATE INDEX IF NOT EXISTS idx_karticles_featured ON public.knowledge_articles(is_featured);
CREATE INDEX IF NOT EXISTS idx_karticles_drive_id ON public.knowledge_articles(drive_file_id);

-- 3. READING PROGRESS TABLE
CREATE TABLE IF NOT EXISTS public.knowledge_reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES public.knowledge_articles(id) ON DELETE CASCADE,
    last_page INT NOT NULL DEFAULT 1,
    total_pages INT,
    progress_percentage NUMERIC DEFAULT 0,
    last_opened_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_article_progress UNIQUE (user_id, article_id)
);

CREATE INDEX IF NOT EXISTS idx_kreading_user ON public.knowledge_reading_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_kreading_article ON public.knowledge_reading_progress(article_id);

-- 4. BOOKMARKS TABLE
CREATE TABLE IF NOT EXISTS public.knowledge_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES public.knowledge_articles(id) ON DELETE CASCADE,
    page_number INT NOT NULL DEFAULT 1,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_article_page_bookmark UNIQUE (user_id, article_id, page_number)
);

CREATE INDEX IF NOT EXISTS idx_kbookmarks_user ON public.knowledge_bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_kbookmarks_article ON public.knowledge_bookmarks(article_id);

-- 5. RPC FUNCTIONS FOR SECURE OPERATIONS
CREATE OR REPLACE FUNCTION public.increment_article_view(p_article_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_views INT;
BEGIN
    UPDATE public.knowledge_articles
    SET views_count = COALESCE(views_count, 0) + 1,
        updated_at = NOW()
    WHERE id = p_article_id
    RETURNING views_count INTO v_new_views;
    
    RETURN COALESCE(v_new_views, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.save_reading_progress(
    p_article_id UUID,
    p_page INT,
    p_total_pages INT DEFAULT NULL,
    p_percentage NUMERIC DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO public.knowledge_reading_progress (
        user_id,
        article_id,
        last_page,
        total_pages,
        progress_percentage,
        last_opened_at,
        updated_at,
        completed_at
    )
    VALUES (
        v_user_id,
        p_article_id,
        GREATEST(p_page, 1),
        p_total_pages,
        COALESCE(p_percentage, CASE WHEN p_total_pages > 0 THEN (p_page::NUMERIC / p_total_pages::NUMERIC) * 100 ELSE 0 END),
        NOW(),
        NOW(),
        CASE WHEN p_total_pages > 0 AND p_page >= p_total_pages THEN NOW() ELSE NULL END
    )
    ON CONFLICT (user_id, article_id) DO UPDATE SET
        last_page = EXCLUDED.last_page,
        total_pages = COALESCE(EXCLUDED.total_pages, public.knowledge_reading_progress.total_pages),
        progress_percentage = EXCLUDED.progress_percentage,
        last_opened_at = NOW(),
        updated_at = NOW(),
        completed_at = CASE 
            WHEN EXCLUDED.total_pages > 0 AND EXCLUDED.last_page >= EXCLUDED.total_pages THEN NOW()
            ELSE public.knowledge_reading_progress.completed_at
        END;
END;
$$;

CREATE OR REPLACE FUNCTION public.toggle_article_bookmark(
    p_article_id UUID,
    p_page INT DEFAULT 1,
    p_note TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.knowledge_bookmarks 
        WHERE user_id = v_user_id AND article_id = p_article_id AND page_number = p_page
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.knowledge_bookmarks 
        WHERE user_id = v_user_id AND article_id = p_article_id AND page_number = p_page;
        RETURN FALSE;
    ELSE
        INSERT INTO public.knowledge_bookmarks (user_id, article_id, page_number, note)
        VALUES (v_user_id, p_article_id, p_page, p_note);
        RETURN TRUE;
    END IF;
END;
$$;

-- 6. ROW LEVEL SECURITY POLICIES

-- Enable RLS
ALTER TABLE public.knowledge_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_reading_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_bookmarks ENABLE ROW LEVEL SECURITY;

-- Categories RLS
DROP POLICY IF EXISTS "categories_read_policy" ON public.knowledge_categories;
CREATE POLICY "categories_read_policy" ON public.knowledge_categories
    FOR SELECT USING (is_active = true OR public.get_auth_role() IN ('super_admin', 'evaluating_doctor', 'leader'));

DROP POLICY IF EXISTS "categories_admin_manage_policy" ON public.knowledge_categories;
CREATE POLICY "categories_admin_manage_policy" ON public.knowledge_categories
    FOR ALL USING (public.get_auth_role() IN ('super_admin', 'evaluating_doctor'));

-- Articles RLS
DROP POLICY IF EXISTS "knowledge_articles_read" ON public.knowledge_articles;
CREATE POLICY "knowledge_articles_read" ON public.knowledge_articles
    FOR SELECT USING (
        is_published = true 
        OR author_id = auth.uid() 
        OR public.get_auth_role() IN ('super_admin', 'evaluating_doctor', 'leader')
    );

DROP POLICY IF EXISTS "knowledge_articles_manage" ON public.knowledge_articles;
CREATE POLICY "knowledge_articles_manage" ON public.knowledge_articles
    FOR ALL USING (
        public.get_auth_role() = 'super_admin' 
        OR (public.get_auth_role() = 'evaluating_doctor' AND (author_id = auth.uid() OR author_id IS NULL))
    );

-- Reading Progress RLS
DROP POLICY IF EXISTS "reading_progress_user_policy" ON public.knowledge_reading_progress;
CREATE POLICY "reading_progress_user_policy" ON public.knowledge_reading_progress
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Bookmarks RLS
DROP POLICY IF EXISTS "bookmarks_user_policy" ON public.knowledge_bookmarks;
CREATE POLICY "bookmarks_user_policy" ON public.knowledge_bookmarks
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 7. GRANT PERMISSIONS
GRANT ALL ON public.knowledge_categories TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.knowledge_articles TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.knowledge_reading_progress TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.knowledge_bookmarks TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.increment_article_view(UUID) TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_reading_progress(UUID, INT, INT, NUMERIC) TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.toggle_article_bookmark(UUID, INT, TEXT) TO postgres, anon, authenticated, service_role;

-- 8. INITIAL SEED FOR MAIN CATEGORIES & SUBCATEGORIES
DO $$
DECLARE
    v_sci_ref_id UUID := '00000000-0000-0000-0000-000000000007'::UUID;
BEGIN
    -- Top 7 Main Categories
    INSERT INTO public.knowledge_categories (id, name_ar, description, icon_name, order_index, is_active, parent_id)
    VALUES 
        ('00000000-0000-0000-0000-000000000001', 'الإجراءات التمريضية', 'دليل الإجراءات والخطوات العملية والبروتوكولات السريرية', 'assignment', 1, true, NULL),
        ('00000000-0000-0000-0000-000000000002', 'الأمراض والحالات المرضية', 'شرح الحالات المرضية الشائعة والرعاية التمريضية المرتبطة بها', 'healing', 2, true, NULL),
        ('00000000-0000-0000-0000-000000000003', 'الأدوية والمعلومات الدوائية', 'المعلومات الدوائية، الحسابات، المحاليل والجرعات الإكلينيكية', 'medication', 3, true, NULL),
        ('00000000-0000-0000-0000-000000000004', 'التثقيف الصحي', 'إرشادات التوعية والتثقيف الصحي للمرضى والمجتمع', 'favorite', 4, true, NULL),
        ('00000000-0000-0000-0000-000000000005', 'ملاحظات ودروس للطلاب', 'شروحات وملخصات ودروس إكلينيكية لطلاب الامتياز', 'school', 5, true, NULL),
        ('00000000-0000-0000-0000-000000000006', 'محتوى عام', 'توجيهات عامة وأخلاقيات المهنة وإرشادات العمل السريري', 'article', 6, true, NULL),
        (v_sci_ref_id, 'المراجع العلمية', 'مراجع وكتب وأبحاث سريرية معتمدة بصيغة PDF', 'menu_book', 7, true, NULL)
    ON CONFLICT (id) DO UPDATE SET
        name_ar = EXCLUDED.name_ar,
        description = EXCLUDED.description,
        icon_name = EXCLUDED.icon_name,
        order_index = EXCLUDED.order_index,
        is_active = true;

    -- Subcategories under "المراجع العلمية"
    INSERT INTO public.knowledge_categories (id, parent_id, name_ar, description, icon_name, order_index, is_active)
    VALUES
        ('00000000-0000-0000-0000-000000000101', v_sci_ref_id, 'أساسيات التمريض', 'الأسس التمريضية والإجراءات التأسيسية', 'menu_book', 1, true),
        ('00000000-0000-0000-0000-000000000102', v_sci_ref_id, 'العناية المركزة', 'بروتوكولات وكتب الحالات الحرجة وICU', 'monitor_heart', 2, true),
        ('00000000-0000-0000-0000-000000000103', v_sci_ref_id, 'تمريض الأطفال', 'رعاية الأطفال وحديثي الولادة والحضانات NICU', 'child_care', 3, true),
        ('00000000-0000-0000-0000-000000000104', v_sci_ref_id, 'تمريض الباطنة والجراحة', 'المراجع الشاملة للباطنة والجراحة', 'local_hospital', 4, true),
        ('00000000-0000-0000-0000-000000000105', v_sci_ref_id, 'تمريض النساء والتوليد', 'رعاية الأمومة والنساء والتوليد', 'pregnant_woman', 5, true),
        ('00000000-0000-0000-0000-000000000106', v_sci_ref_id, 'طب وطوارئ التمريض', 'إسعافات أولية وطوارئ واستقبال', 'emergency', 6, true),
        ('00000000-0000-0000-0000-000000000107', v_sci_ref_id, 'مكافحة العدوى', 'التعقيم واحتياطات العزل والسلامة', 'sanitizer', 7, true),
        ('00000000-0000-0000-0000-000000000108', v_sci_ref_id, 'علم الأدوية والفارماكولوجي', 'المراجع الدوائية والجرعات والتداخلات', 'medication', 8, true),
        ('00000000-0000-0000-0000-000000000109', v_sci_ref_id, 'التشريح والفسيولوجي', 'علم وظائف الأعضاء والتشريح البشري', 'biotech', 9, true),
        ('00000000-0000-0000-0000-000000000110', v_sci_ref_id, 'الصحة النفسية', 'التمريض النفسي وعلاج الاضطرابات', 'psychology', 10, true),
        ('00000000-0000-0000-0000-000000000111', v_sci_ref_id, 'التمريض المجتمعي', 'الصحة العامة وطب المجتمع', 'groups', 11, true),
        ('00000000-0000-0000-0000-000000000112', v_sci_ref_id, 'أبحاث ومراجع عامة', 'المجلات والأوراق البحثية والمراجع الإكلينيكية العامة', 'auto_stories', 12, true)
    ON CONFLICT (id) DO UPDATE SET
        parent_id = EXCLUDED.parent_id,
        name_ar = EXCLUDED.name_ar,
        description = EXCLUDED.description,
        icon_name = EXCLUDED.icon_name,
        order_index = EXCLUDED.order_index,
        is_active = true;
END $$;
