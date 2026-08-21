-- Safe handle_new_user trigger function
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
    gender,
    marital_status,
    children_count,
    is_matrouh_resident,
    role
  )
  VALUES (
    new.id,
    COALESCE(new.email, ''),
    COALESCE(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    COALESCE(new.raw_user_meta_data->>'university_code', 'NUR-' || substring(new.id::text from 1 for 8)),
    COALESCE(new.raw_user_meta_data->>'phone_number', '01000000000'),
    COALESCE(new.raw_user_meta_data->>'emergency_contact', '01000000000'),
    'male',
    'أعزب',
    0,
    true,
    'student'::user_role
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
