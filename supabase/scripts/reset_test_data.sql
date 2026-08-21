-- ========================================================
-- PROJECT: إمتياز مطروح (Nurse Matrouh)
-- Clean Test Data Reset Script (Preserves Schema & RLS)
-- Date: 2026-08-15
-- ========================================================

-- 1. TRUNCATE TEST DATA TABLES WITH CASCADE
TRUNCATE TABLE 
  public.attendance,
  public.roster_entries,
  public.shift_requests,
  public.rosters,
  public.disciplinary_actions,
  public.evaluations,
  public.case_handovers,
  public.cases,
  public.quiz_answers,
  public.quiz_attempts,
  public.notifications,
  public.audit_logs
RESTART IDENTITY CASCADE;

-- 2. CLEAR NON-ADMIN PROFILES (Keep Super Admin if exists)
DELETE FROM public.profiles WHERE role != 'super_admin';

-- 3. ENSURE ESSENTIAL DEPARTMENTS
INSERT INTO public.departments (id, name_ar, name_en, description, capacity) VALUES
('a0000001-0000-0000-0000-000000000001', 'قسم الطوارئ', 'Emergency Department', 'استقبال وحالات الطوارئ الحرجة والرعاية السريعة', 30),
('a0000001-0000-0000-0000-000000000002', 'عناية جراحة', 'Surgical ICU', 'رعاية ما بعد الجراحات الحرجة', 15),
('a0000001-0000-0000-0000-000000000003', 'عناية باطنة', 'Medical ICU', 'عناية فائقة للأمراض الباطنية الحرجة', 15),
('a0000001-0000-0000-0000-000000000004', 'حضانة الأطفال (NICU)', 'Neonatal ICU', 'رعاية حديثي الولادة والمبتسرين', 20),
('a0000001-0000-0000-0000-000000000005', 'عناية القلب (CCU)', 'Cardiac Care Unit', 'متابعة مرضى الأزمات القلبية والقسطرة', 15),
('a0000001-0000-0000-0000-000000000006', 'قسم الغسيل الكلوي', 'Dialysis Unit', 'جلسات الغسيل الكلوي الدوري والمستمر', 25)
ON CONFLICT (id) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  capacity = EXCLUDED.capacity;

-- 4. ENSURE ESSENTIAL SHIFTS
INSERT INTO public.shifts (code, name_ar, start_time, end_time, hours_count) VALUES
('morning', 'صباحي (Morning)', '08:00:00', '14:00:00', 6),
('evening', 'مسائي (Evening)', '14:00:00', '20:00:00', 6),
('long',    'طويل (Long)',     '08:00:00', '20:00:00', 12),
('night',   'سهر (Night)',     '20:00:00', '08:00:00', 12),
('absence', 'غياب',            '00:00:00', '00:00:00', 0),
('leave',   'إجازة',           '00:00:00', '00:00:00', 0)
ON CONFLICT (code) DO UPDATE SET
  name_ar = EXCLUDED.name_ar;

-- 5. ENSURE DISCIPLINARY ACTION TYPES
INSERT INTO public.disciplinary_action_types (code, name_ar, default_severity) VALUES
('warning',            'تنبيه شفهي',     1),
('final_warning',      'إنذار رسمي',      2),
('official_violation', 'مخالفة رسمية',    3),
('deduction',          'خصم شيفت/نقاط',  4),
('absence',            'تسجيل غياب',      3),
('reward',             'مكافأة تميز',     0)
ON CONFLICT (code) DO NOTHING;
