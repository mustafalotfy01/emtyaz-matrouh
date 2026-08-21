-- ========================================================
-- Supabase Trigger: Auto-Create Profile on Auth SignUp
-- This runs as a SECURITY DEFINER function in Supabase
-- to create a profile row whenever a new user signs up via Auth
-- ========================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    university_code,
    phone_number,
    emergency_contact,
    role
  )
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    COALESCE(new.raw_user_meta_data->>'university_code', 'PENDING-' || substring(new.id::text from 1 for 8)),
    COALESCE(new.raw_user_meta_data->>'phone_number', '00000000000'),
    COALESCE(new.raw_user_meta_data->>'emergency_contact', '00000000000'),
    COALESCE((new.raw_user_meta_data->>'role')::user_role, 'student')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ========================================================
-- Supabase Realtime: Enable only for needed tables
-- ========================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_handovers;

-- ========================================================
-- Storage Buckets
-- ========================================================
INSERT INTO storage.buckets (id, name, public) VALUES
  ('logos', 'logos', true),
  ('knowledge-pdfs', 'knowledge-pdfs', false),
  ('article-images', 'article-images', true),
  ('quiz-attachments', 'quiz-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies: Public read for logos and article images
CREATE POLICY "Public logos read" ON storage.objects
  FOR SELECT USING (bucket_id = 'logos');

CREATE POLICY "Public article images read" ON storage.objects
  FOR SELECT USING (bucket_id = 'article-images');

-- Authenticated users can upload to knowledge-pdfs
CREATE POLICY "Authenticated knowledge upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'knowledge-pdfs'
    AND auth.role() = 'authenticated'
  );
