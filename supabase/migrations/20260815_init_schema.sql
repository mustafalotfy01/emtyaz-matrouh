-- ========================================================
-- PROJECT: إمتياز مطروح (Nurse Matrouh)
-- Complete Database Initialization & RLS Security Policies
-- Date: 2026-08-15
-- ========================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------
-- 1. ENUMS & CONSTANTS
-- --------------------------------------------------------
CREATE TYPE user_role AS ENUM ('super_admin', 'leader', 'evaluating_doctor', 'student');
CREATE TYPE shift_type AS ENUM ('morning', 'evening', 'long', 'night', 'absence', 'leave');
CREATE TYPE request_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE attendance_status AS ENUM ('present', 'late', 'absent', 'early_leave', 'excused');
CREATE TYPE action_status AS ENUM ('pending', 'approved', 'rejected', 'cancelled', 'appealed', 'resolved');
CREATE TYPE evaluation_type AS ENUM ('reward', 'warning', 'official_violation', 'penalty');
CREATE TYPE case_status AS ENUM ('active', 'pending_handover', 'transferred', 'closed');
CREATE TYPE question_type AS ENUM ('mcq', 'true_false', 'case_study');

-- --------------------------------------------------------
-- 2. ROLES & PERMISSIONS
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name user_role UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL, -- e.g. "roster.approve", "discipline.create"
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id UUID REFERENCES public.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- --------------------------------------------------------
-- 3. PROFILES TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    university_code TEXT UNIQUE NOT NULL,
    phone_number TEXT NOT NULL,
    national_id TEXT,
    gender TEXT CHECK (gender IN ('male', 'female')),
    marital_status TEXT,
    children_count INT DEFAULT 0,
    is_matrouh_resident BOOLEAN DEFAULT true,
    emergency_contact TEXT NOT NULL,
    residence_address TEXT,
    role user_role NOT NULL DEFAULT 'student',
    is_approved BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------
-- 4. DEPARTMENTS, SHIFTS & ATTENDANCE ZONES
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_ar TEXT NOT NULL,
    name_en TEXT NOT NULL,
    description TEXT,
    head_doctor TEXT,
    capacity INT DEFAULT 20,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code shift_type UNIQUE NOT NULL,
    name_ar TEXT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    hours_count INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.attendance_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_id UUID REFERENCES public.departments(id) ON DELETE CASCADE,
    hospital_name TEXT NOT NULL DEFAULT 'مستشفى مطروح العام',
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters DOUBLE PRECISION NOT NULL DEFAULT 150.0, -- Configurable per zone
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------
-- 5. ROSTER & SEPARATED SHIFT REQUESTS
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rosters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    month INT NOT NULL,
    year INT NOT NULL,
    is_published BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.shift_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
    requested_date DATE NOT NULL,
    shift_type shift_type NOT NULL,
    status request_status NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.roster_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    roster_id UUID REFERENCES public.rosters(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
    shift_request_id UUID REFERENCES public.shift_requests(id) ON DELETE SET NULL,
    shift_date DATE NOT NULL,
    shift_type shift_type NOT NULL,
    approved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_roster_date UNIQUE (student_id, shift_date)
);

-- --------------------------------------------------------
-- 6. ATTENDANCE LOGS
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    roster_id UUID REFERENCES public.roster_entries(id) ON DELETE SET NULL,
    department_id UUID REFERENCES public.departments(id) ON DELETE CASCADE,
    check_in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    check_out_time TIMESTAMPTZ,
    check_in_latitude DOUBLE PRECISION,
    check_in_longitude DOUBLE PRECISION,
    geofence_status BOOLEAN DEFAULT true,
    biometric_verified BOOLEAN DEFAULT true, -- Authenticated via device local_auth only
    status attendance_status NOT NULL DEFAULT 'present',
    late_minutes INT DEFAULT 0,
    failure_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------
-- 7. EVALUATIONS, DISCIPLINARY & COMPLIANCE MODULE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.evaluations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
    evaluation_type evaluation_type NOT NULL,
    score INT CHECK (score >= 1 AND score <= 100),
    title TEXT NOT NULL,
    notes TEXT NOT NULL,
    evaluation_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.disciplinary_action_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL, -- e.g. "warning", "violation", "deduction", "absence", "reward"
    name_ar TEXT NOT NULL,
    default_severity INT DEFAULT 1,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.disciplinary_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_name TEXT NOT NULL,
    occurrence_count INT NOT NULL,
    escalated_action_type TEXT NOT NULL,
    deduction_unit TEXT DEFAULT 'points',
    deduction_value DOUBLE PRECISION DEFAULT 0.0,
    time_window_days INT DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.disciplinary_actions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    approved_by UUID REFERENCES public.profiles(id),
    department_id UUID REFERENCES public.departments(id) ON DELETE CASCADE,
    roster_entry_id UUID REFERENCES public.roster_entries(id) ON DELETE SET NULL,
    attendance_id UUID REFERENCES public.attendance(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL,
    severity INT DEFAULT 1,
    reason TEXT NOT NULL,
    description TEXT NOT NULL,
    deduction_value DOUBLE PRECISION DEFAULT 0.0,
    deduction_unit TEXT DEFAULT 'points',
    deduction_reason TEXT,
    absence_days INT DEFAULT 0,
    status action_status NOT NULL DEFAULT 'pending',
    action_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------
-- 8. AUDIT LOGS & SETTINGS
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    entity_id TEXT,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------
-- 9. QUIZZES, CASES, KNOWLEDGE & NOTIFICATIONS
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.quizzes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    department_id UUID REFERENCES public.departments(id) ON DELETE CASCADE,
    created_by UUID REFERENCES public.profiles(id),
    time_limit_minutes INT NOT NULL DEFAULT 15,
    passing_score INT NOT NULL DEFAULT 60,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.quiz_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quiz_id UUID NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    type question_type NOT NULL DEFAULT 'mcq',
    options JSONB NOT NULL,
    correct_option_index INT NOT NULL,
    explanation TEXT
);

CREATE TABLE IF NOT EXISTS public.quiz_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_id UUID REFERENCES public.quiz_questions(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    is_correct BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quiz_id UUID NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    score_percentage DOUBLE PRECISION NOT NULL,
    passed BOOLEAN NOT NULL,
    completed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.quiz_answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attempt_id UUID REFERENCES public.quiz_attempts(id) ON DELETE CASCADE,
    question_id UUID REFERENCES public.quiz_questions(id) ON DELETE CASCADE,
    selected_option_index INT,
    is_correct BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.cases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_code TEXT UNIQUE NOT NULL, -- Anonymized e.g. "CASE-2026-0891"
    department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
    current_student_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    supervisor_doctor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    chief_complaint TEXT NOT NULL,
    current_condition TEXT NOT NULL,
    important_findings TEXT,
    procedures_done TEXT,
    pending_tasks TEXT,
    status case_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.case_handovers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
    from_student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    to_student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    handover_notes TEXT NOT NULL,
    status request_status NOT NULL DEFAULT 'pending',
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.knowledge_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_ar TEXT NOT NULL,
    icon_name TEXT DEFAULT 'book',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.knowledge_articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES public.knowledge_categories(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    summary TEXT NOT NULL,
    content_markdown TEXT NOT NULL,
    type TEXT CHECK (type IN ('disease', 'procedure', 'emergency', 'medication', 'tip')),
    author_id UUID REFERENCES public.profiles(id),
    is_published BOOLEAN DEFAULT true,
    views_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.knowledge_attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID REFERENCES public.knowledge_articles(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'general',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ========================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roster_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disciplinary_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_handovers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS user_role AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Profiles: Own profile or Leaders/Admins/Doctors
DROP POLICY IF EXISTS "Profiles read" ON public.profiles;
CREATE POLICY "Profiles read" ON public.profiles
    FOR SELECT USING (auth.uid() = id OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor'));

-- Shift Requests: Students insert/read own, Leaders manage
DROP POLICY IF EXISTS "Shift requests student select" ON public.shift_requests;
CREATE POLICY "Shift requests student select" ON public.shift_requests
    FOR SELECT USING (student_id = auth.uid() OR public.get_auth_role() IN ('super_admin', 'leader'));

DROP POLICY IF EXISTS "Shift requests student insert" ON public.shift_requests;
CREATE POLICY "Shift requests student insert" ON public.shift_requests
    FOR INSERT WITH CHECK (student_id = auth.uid());

-- Disciplinary Actions: Student reads own approved actions, Leader/Doctor creates/reads
DROP POLICY IF EXISTS "Disciplinary actions student select" ON public.disciplinary_actions;
CREATE POLICY "Disciplinary actions student select" ON public.disciplinary_actions
    FOR SELECT USING (student_id = auth.uid() OR public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor'));

DROP POLICY IF EXISTS "Disciplinary actions leader insert" ON public.disciplinary_actions;
CREATE POLICY "Disciplinary actions leader insert" ON public.disciplinary_actions
    FOR INSERT WITH CHECK (public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor'));
