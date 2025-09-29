-- Core database schema for the Japanese tutoring application.
-- This version keeps the footprint small while supporting:
-- * user management for tutors and students
-- * calendar-based availability that exposes minutes the tutor opens up
-- * lesson bookings (including intro/free minutes)
-- * payments, debt tracking, and fraud alerts

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role TEXT NOT NULL CHECK (role IN ('tutor', 'student')),
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    timezone TEXT DEFAULT 'Asia/Tokyo',
    locale TEXT DEFAULT 'ja-JP',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    marketing_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
    anonymized_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    CHECK (anonymized_at IS NULL OR anonymized_at >= created_at)
);

CREATE TABLE tutor_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    introduction TEXT,
    native_language TEXT DEFAULT 'Japanese',
    teaching_languages TEXT[] DEFAULT ARRAY['Japanese'],
    hourly_rate NUMERIC(8,2) CHECK (hourly_rate IS NULL OR hourly_rate > 0),
    intro_offer_minutes INTEGER NOT NULL DEFAULT 25 CHECK (intro_offer_minutes >= 0),
    intro_offer_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    default_session_minutes INTEGER NOT NULL DEFAULT 50 CHECK (default_session_minutes > 0),
    booking_increment_minutes INTEGER NOT NULL DEFAULT 25 CHECK (booking_increment_minutes > 0),
    max_daily_minutes INTEGER CHECK (max_daily_minutes IS NULL OR max_daily_minutes > 0),
    calendar_timezone TEXT,
    notes TEXT
);

CREATE TABLE student_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    proficiency_level TEXT CHECK (proficiency_level IN (
        'beginner',
        'elementary',
        'intermediate',
        'advanced'
    )),
    learning_goal TEXT,
    preferred_topics TEXT[],
    intro_minutes_redeemed INTEGER NOT NULL DEFAULT 0,
    joined_via_referral BOOLEAN NOT NULL DEFAULT FALSE
);

-- Tutors define recurring availability windows that power the booking calendar.
CREATE TABLE tutor_availability_patterns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tutor_id UUID NOT NULL REFERENCES tutor_profiles(user_id) ON DELETE CASCADE,
    weekday SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    start_time TIME WITHOUT TIME ZONE NOT NULL,
    end_time TIME WITHOUT TIME ZONE NOT NULL,
    slot_minutes INTEGER NOT NULL DEFAULT 25 CHECK (slot_minutes > 0),
    allow_intro_sessions BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (end_time > start_time),
    UNIQUE (tutor_id, weekday, start_time, end_time)
);

-- Specific dates the tutor is unavailable or adds extra capacity.
CREATE TABLE tutor_availability_overrides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tutor_id UUID NOT NULL REFERENCES tutor_profiles(user_id) ON DELETE CASCADE,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    available_minutes INTEGER CHECK (available_minutes IS NULL OR available_minutes > 0),
    override_type TEXT NOT NULL CHECK (override_type IN ('time_off', 'extra_time')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (end_at > start_at),
    UNIQUE (tutor_id, start_at, end_at)
);

-- Lesson bookings connect students with the tutor at specific times.
CREATE TABLE lesson_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tutor_id UUID NOT NULL REFERENCES tutor_profiles(user_id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    scheduled_start TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN (
        'requested',
        'confirmed',
        'completed',
        'cancelled',
        'no_show'
    )),
    is_intro_session BOOLEAN NOT NULL DEFAULT FALSE,
    intro_minutes_applied INTEGER NOT NULL DEFAULT 0 CHECK (
        intro_minutes_applied >= 0 AND intro_minutes_applied <= duration_minutes
    ),
    meeting_link TEXT,
    location TEXT,
    price_per_minute NUMERIC(8,2) CHECK (price_per_minute IS NULL OR price_per_minute >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (tutor_id, student_id, scheduled_start)
);

CREATE TABLE lesson_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES lesson_bookings(id) ON DELETE CASCADE,
    summary TEXT,
    homework TEXT,
    vocabulary TEXT[],
    next_focus TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (booking_id)
);

CREATE TABLE study_materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tutor_id UUID NOT NULL REFERENCES tutor_profiles(user_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    resource_url TEXT,
    tags TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (tutor_id, title)
);

CREATE TABLE lesson_materials (
    booking_id UUID NOT NULL REFERENCES lesson_bookings(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES study_materials(id) ON DELETE CASCADE,
    PRIMARY KEY (booking_id, material_id)
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES lesson_bookings(id) ON DELETE SET NULL,
    tutor_id UUID NOT NULL REFERENCES tutor_profiles(user_id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    currency TEXT NOT NULL DEFAULT 'JPY',
    status TEXT NOT NULL CHECK (status IN (
        'pending',
        'authorized',
        'captured',
        'refunded',
        'failed'
    )),
    provider TEXT,
    provider_reference TEXT,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, provider_reference)
);

CREATE TABLE student_debts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    tutor_id UUID NOT NULL REFERENCES tutor_profiles(user_id) ON DELETE CASCADE,
    booking_id UUID REFERENCES lesson_bookings(id) ON DELETE SET NULL,
    amount_due NUMERIC(10,2) NOT NULL CHECK (amount_due > 0),
    due_date DATE,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'written_off')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    UNIQUE (student_id, tutor_id, booking_id)
);

CREATE TABLE fraud_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    reason TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
    flagged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    UNIQUE (user_id, source, reason)
);

-- Lightweight GDPR helpers keep the data lifecycle auditable without
-- over-complicating the solo tutor workflow.
CREATE TABLE privacy_consents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_type TEXT NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    withdrawn_at TIMESTAMPTZ,
    notes TEXT,
    CHECK (withdrawn_at IS NULL OR withdrawn_at > granted_at),
    UNIQUE (user_id, consent_type, granted_at)
);

CREATE TABLE data_erasure_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',
        'in_progress',
        'completed',
        'rejected'
    )),
    processed_at TIMESTAMPTZ,
    notes TEXT,
    CHECK (
        processed_at IS NULL
        OR processed_at >= requested_at
    )
);

-- Quick view to list upcoming confirmed bookings with the relevant student details.
CREATE VIEW upcoming_lessons AS
SELECT
    b.id,
    b.scheduled_start,
    b.duration_minutes,
    b.status,
    b.is_intro_session,
    s.full_name AS student_name,
    sp.proficiency_level,
    sp.learning_goal,
    b.meeting_link
FROM lesson_bookings b
JOIN users s ON b.student_id = s.id
JOIN student_profiles sp ON sp.user_id = s.id
WHERE b.status IN ('confirmed', 'requested')
ORDER BY b.scheduled_start;
