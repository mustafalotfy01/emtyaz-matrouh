-- ========================================================
-- RLS POLICIES FOR PUBLIC & REFERENCE TABLES
-- ========================================================

-- Enable RLS on reference tables
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disciplinary_action_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disciplinary_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_options ENABLE ROW LEVEL SECURITY;

-- Public/Authenticated read policies for reference data
DROP POLICY IF EXISTS "Public departments read" ON public.departments;
CREATE POLICY "Public departments read" ON public.departments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public shifts read" ON public.shifts;
CREATE POLICY "Public shifts read" ON public.shifts FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public attendance_zones read" ON public.attendance_zones;
CREATE POLICY "Public attendance_zones read" ON public.attendance_zones FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public action_types read" ON public.disciplinary_action_types;
CREATE POLICY "Public action_types read" ON public.disciplinary_action_types FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public rules read" ON public.disciplinary_rules;
CREATE POLICY "Public rules read" ON public.disciplinary_rules FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public categories read" ON public.knowledge_categories;
CREATE POLICY "Public categories read" ON public.knowledge_categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public articles read" ON public.knowledge_articles;
CREATE POLICY "Public articles read" ON public.knowledge_articles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public attachments read" ON public.knowledge_attachments;
CREATE POLICY "Public attachments read" ON public.knowledge_attachments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public quizzes read" ON public.quizzes;
CREATE POLICY "Public quizzes read" ON public.quizzes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public quiz_questions read" ON public.quiz_questions;
CREATE POLICY "Public quiz_questions read" ON public.quiz_questions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public quiz_options read" ON public.quiz_options;
CREATE POLICY "Public quiz_options read" ON public.quiz_options FOR SELECT USING (true);
