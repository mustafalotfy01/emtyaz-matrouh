-- ========================================================
-- PROJECT: إمتياز مطروح (Nurse Matrouh)
-- Demo Seed Data Script (Production-Safe Seeding)
-- Date: 2026-08-15
-- ========================================================

-- 1. Insert Departments
INSERT INTO public.departments (id, name_ar, name_en, description, capacity) VALUES
('a0000001-0000-0000-0000-000000000001', 'قسم الطوارئ', 'Emergency Department', 'استقبال وحالات الطوارئ الحرجة والرعاية السريعة', 30),
('a0000001-0000-0000-0000-000000000002', 'عناية جراحة', 'Surgical ICU', 'رعاية ما بعد الجراحات الحرجة', 15),
('a0000001-0000-0000-0000-000000000003', 'عناية باطنة', 'Medical ICU', 'عناية فائقة للأمراض الباطنية الحرجة', 15),
('a0000001-0000-0000-0000-000000000004', 'حضانة الأطفال (NICU)', 'Neonatal ICU', 'رعاية حديثي الولادة والمبتسرين', 20),
('a0000001-0000-0000-0000-000000000005', 'عناية القلب (CCU)', 'Cardiac Care Unit', 'متابعة مرضى الأزمات القلبية والقسطرة', 15),
('a0000001-0000-0000-0000-000000000006', 'قسم الغسيل الكلوي', 'Dialysis Unit', 'جلسات الغسيل الكلوي الدوري والمستمر', 25)
ON CONFLICT (id) DO NOTHING;

-- 2. Insert Shifts
INSERT INTO public.shifts (code, name_ar, start_time, end_time, hours_count) VALUES
('morning', 'صباحي (Morning)', '08:00:00', '14:00:00', 6),
('evening', 'مسائي (Evening)', '14:00:00', '20:00:00', 6),
('long',    'طويل (Long)',     '08:00:00', '20:00:00', 12),
('night',   'سهر (Night)',     '20:00:00', '08:00:00', 12),
('absence', 'غياب',            '00:00:00', '00:00:00', 0),
('leave',   'إجازة',           '00:00:00', '00:00:00', 0)
ON CONFLICT (code) DO NOTHING;

-- 3. Insert Attendance Zones (Matrouh General Hospital)
INSERT INTO public.attendance_zones (id, department_id, hospital_name, latitude, longitude, radius_meters) VALUES
('b0000002-0000-0000-0000-000000000001', 'a0000001-0000-0000-0000-000000000001', 'مستشفى مطروح العام', 31.3543, 27.2373, 150.0)
ON CONFLICT (id) DO NOTHING;

-- 4. Insert Disciplinary Action Types
INSERT INTO public.disciplinary_action_types (code, name_ar, default_severity) VALUES
('warning',            'تنبيه شفهي',     1),
('final_warning',      'إنذار رسمي',      2),
('official_violation', 'مخالفة رسمية',    3),
('deduction',          'خصم شيفت/نقاط',  4),
('absence',            'تسجيل غياب',      3),
('reward',             'مكافأة تميز',     0)
ON CONFLICT (code) DO NOTHING;

-- 5. Insert Disciplinary Rules (Escalation Engine)
INSERT INTO public.disciplinary_rules (rule_name, occurrence_count, escalated_action_type, deduction_unit, deduction_value) VALUES
('تأخير أول',               1, 'warning',            'points', 2.0),
('تأخير مكرر مرتين',        2, 'final_warning',      'points', 5.0),
('غياب بدون إذن أول',       1, 'official_violation', 'shifts', 1.0)
ON CONFLICT DO NOTHING;

-- 6. Insert Roles
INSERT INTO public.roles (name, description) VALUES
('super_admin',       'الإدارة العليا — صلاحيات كاملة'),
('leader',            'منسق الجدولة والامتياز'),
('evaluating_doctor', 'الدكتور المقيّم'),
('student',           'طالب امتياز')
ON CONFLICT (name) DO NOTHING;

-- 7. Insert Permissions
INSERT INTO public.permissions (code, description) VALUES
('roster.view',           'عرض الروستر'),
('roster.create',         'إنشاء شيفت'),
('roster.approve',        'اعتماد طلبات الشيفتات'),
('attendance.checkin',    'تسجيل حضور'),
('attendance.view',       'عرض سجل الحضور'),
('discipline.create',     'إصدار إجراء تأديبي'),
('discipline.approve',    'اعتماد إجراء تأديبي'),
('quiz.take',             'أداء اختبار'),
('quiz.create',           'إنشاء اختبار'),
('knowledge.view',        'عرض المقالات التعليمية'),
('knowledge.create',      'إنشاء مقال تعليمي'),
('case.handover',         'تسليم حالة مريض'),
('analytics.leader',      'إحصائيات المنسق'),
('analytics.admin',       'إحصائيات الإدارة')
ON CONFLICT (code) DO NOTHING;

-- 8. Insert Knowledge Categories
INSERT INTO public.knowledge_categories (id, name_ar, icon_name) VALUES
('c0000003-0000-0000-0000-000000000001', 'الإجراءات التمريضية المعقمة', 'procedure'),
('c0000003-0000-0000-0000-000000000002', 'أمراض العناية المركزة والطوارئ', 'disease'),
('c0000003-0000-0000-0000-000000000003', 'التمريض الدوائي والجرعات', 'medication'),
('c0000003-0000-0000-0000-000000000004', 'الإسعافات الأولية والطوارئ', 'emergency')
ON CONFLICT (id) DO NOTHING;

-- 9. Insert Knowledge Articles
INSERT INTO public.knowledge_articles (id, category_id, title, summary, content_markdown, type) VALUES
(
  'e0000004-0000-0000-0000-000000000001',
  'c0000003-0000-0000-0000-000000000001',
  'تركيب القسطرة البولية (Foley Catheter Insertion)',
  'دليل الخطوات المعقمة والتجهيزات اللازمة لتركيب وتثبيت قسطرة البول للذكور والإناث',
  E'# تركيب القسطرة البولية\n\n## المعدات اللازمة\n- قسطرة Foley مقاس مناسب\n- محلول Povidone Iodine\n- قفازات معقمة\n- محقن بمحلول ملحي\n\n## الخطوات\n1. تجهيز المريض وشرح الإجراء\n2. ارتداء القفازات المعقمة\n3. تنظيف المنطقة بـ Povidone Iodine\n4. إدخال القسطرة بلطف\n5. نفخ البالون بـ 10 مل محلول ملحي\n6. التحقق من تدفق البول وتثبيت الأنبوب',
  'procedure'
),
(
  'e0000004-0000-0000-0000-000000000002',
  'c0000003-0000-0000-0000-000000000001',
  'تركيب الرايل التغذوي (NG Tube Insertion)',
  'إدخال أنبوب التغذية والنزح المعدي عبر الأنف وتأكيد موقعه',
  E'# تركيب الرايل التغذوي\n\n## المعدات\n- أنبوب NG مقاس 14 أو 16 FR\n- جل مخدر\n- محقن 60 مل\n\n## خطوات التركيب\n1. قياس الطول NEX (Nose-Earlobe-Xiphoid)\n2. تشحيم طرف الأنبوب\n3. إدخاله من الأنف باتجاه المعدة\n4. التحقق من الموضع بـ X-Ray أو بحقن هواء\n5. تثبيت الأنبوب على الأنف',
  'procedure'
),
(
  'e0000004-0000-0000-0000-000000000003',
  'c0000003-0000-0000-0000-000000000004',
  'خوارزمية إنعاش القلب الرئوي (CPR) — BLS',
  'خطوات Basic Life Support الحديثة وفق AHA 2020 للبالغين',
  E'# إنعاش القلب الرئوي (BLS)\n\n## تسلسل C-A-B\n1. **C - Compressions**: ضغط على الصدر 30 ضغطة\n2. **A - Airway**: فتح مجرى الهواء\n3. **B - Breathing**: نفسين إنقاذيين\n\n## معدل الضغط\n- 100-120 ضغطة/دقيقة\n- عمق 5-6 سم\n\n## نسبة الضغط:التنفس\n- 30:2 للبالغين',
  'emergency'
)
ON CONFLICT (id) DO NOTHING;

-- 10. Insert Demo Quizzes
INSERT INTO public.quizzes (id, title, description, department_id, time_limit_minutes, passing_score) VALUES
(
  'f0000005-0000-0000-0000-000000000001',
  'اختبار الإجراءات التمريضية المعقمة',
  'اختبار شامل في مبادئ التعقيم وتقنيات التمريض المعقمة',
  'a0000001-0000-0000-0000-000000000001',
  15,
  60
),
(
  'f0000005-0000-0000-0000-000000000002',
  'اختبار الطوارئ والإنعاش القلبي الرئوي',
  'أسئلة في BLS وALS وإدارة حالات الطوارئ',
  'a0000001-0000-0000-0000-000000000001',
  20,
  70
)
ON CONFLICT (id) DO NOTHING;

-- 11. Insert Demo Quiz Questions
INSERT INTO public.quiz_questions (id, quiz_id, question_text, type, options, correct_option_index, explanation) VALUES
(
  'ff000001-0000-0000-0000-000000000001',
  'f0000005-0000-0000-0000-000000000001',
  'ما هو حجم محلول ملحي المستخدم لنفخ بالون قسطرة Foley؟',
  'mcq',
  '["5 مل", "10 مل", "20 مل", "30 مل"]',
  1,
  'يُستخدم 10 مل من المحلول الملحي لنفخ بالون قسطرة Foley القياسية لضمان تثبيت القسطرة بالكمية الصحيحة دون تمزق البالون.'
),
(
  'ff000001-0000-0000-0000-000000000002',
  'f0000005-0000-0000-0000-000000000001',
  'ما هو ترتيب C-A-B في الإنعاش القلبي الرئوي وفق AHA 2020؟',
  'mcq',
  '["Compressions - Airway - Breathing", "Airway - Breathing - Compressions", "Breathing - Airway - Compressions", "Compressions - Breathing - Airway"]',
  0,
  'وفق إرشادات AHA 2020، يبدأ الإنعاش بضغطات الصدر أولاً (C) ثم فتح مجرى الهواء (A) ثم التنفس الإنقاذي (B).'
),
(
  'ff000001-0000-0000-0000-000000000003',
  'f0000005-0000-0000-0000-000000000002',
  'ما هو معدل ضغطات الصدر الصحيح في CPR للبالغين؟',
  'mcq',
  '["60-80 ضغطة/دقيقة", "80-100 ضغطة/دقيقة", "100-120 ضغطة/دقيقة", "120-140 ضغطة/دقيقة"]',
  2,
  'المعدل الصحيح هو 100-120 ضغطة في الدقيقة بعمق 5-6 سم لضمان فعالية الضخ القلبي.'
)
ON CONFLICT (id) DO NOTHING;
