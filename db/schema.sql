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
    country_code CHAR(2),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    marketing_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
    stripe_customer_id TEXT,
    auth_provider_id TEXT,
    last_sign_in_ip INET,
    anonymized_at TIMESTAMPTZ,
    data_retention_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    CHECK (anonymized_at IS NULL OR anonymized_at >= created_at),
    CHECK (
        data_retention_expires_at IS NULL
        OR data_retention_expires_at >= created_at
    ),
    UNIQUE (auth_provider_id),
    UNIQUE (stripe_customer_id)
);

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_country ON users(country_code);

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
    notification_email TEXT,
    jitsi_display_name TEXT,
    availability_buffer_minutes INTEGER NOT NULL DEFAULT 5 CHECK (availability_buffer_minutes >= 0),
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
    joined_via_referral BOOLEAN NOT NULL DEFAULT FALSE,
    consented_to_recordings BOOLEAN NOT NULL DEFAULT FALSE
);

-- Auth.js compatible identity mapping for the Next.js front-end.
CREATE TABLE auth_identities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_account_id TEXT NOT NULL,
    access_token TEXT,
    refresh_token TEXT,
    scopes TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, provider_account_id)
);

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ,
    ip_address INET,
    user_agent TEXT
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
    stripe_payment_intent_id TEXT,
    jitsi_domain TEXT NOT NULL DEFAULT 'meet.jit.si',
    meeting_room_name TEXT GENERATED ALWAYS AS (
        lower(replace(format('tutor%s_booking%s', tutor_id::text, id::text), '-', ''))
    ) STORED,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    fraud_risk_score NUMERIC(5,2) CHECK (fraud_risk_score IS NULL OR (
        fraud_risk_score >= 0 AND fraud_risk_score <= 100
    )),
    manual_review_required BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (tutor_id, student_id, scheduled_start),
    UNIQUE (stripe_payment_intent_id)
);

CREATE INDEX idx_lesson_bookings_status ON lesson_bookings(status, scheduled_start);
CREATE INDEX idx_lesson_bookings_manual_review ON lesson_bookings(manual_review_required) WHERE manual_review_required;

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

-- Real-time friendly messaging between tutor and student.
CREATE TABLE chat_threads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tutor_id UUID NOT NULL REFERENCES tutor_profiles(user_id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES student_profiles(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_message_at TIMESTAMPTZ,
    UNIQUE (tutor_id, student_id)
);

CREATE INDEX idx_chat_threads_last_message ON chat_threads(last_message_at DESC);

CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    sse_event_id UUID DEFAULT uuid_generate_v4(),
    metadata JSONB DEFAULT '{}',
    CHECK (metadata IS NOT NULL)
);

CREATE INDEX idx_chat_messages_sender ON chat_messages(sender_id);

CREATE INDEX idx_chat_messages_thread_sent_at ON chat_messages(thread_id, sent_at DESC);

CREATE TABLE chat_message_receipts (
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receipt_type TEXT NOT NULL CHECK (receipt_type IN ('delivered', 'read')),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, user_id, receipt_type)
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
    stripe_charge_id TEXT,
    stripe_payment_intent_id TEXT,
    billing_country CHAR(2),
    card_country CHAR(2),
    billing_ip INET,
    metadata JSONB DEFAULT '{}',
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, provider_reference),
    UNIQUE (stripe_charge_id),
    UNIQUE (stripe_payment_intent_id)
);

CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_student ON payments(student_id);

CREATE TABLE payment_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id UUID REFERENCES payments(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (payload IS NOT NULL)
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

CREATE INDEX idx_student_debts_status ON student_debts(status);

CREATE TABLE fraud_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    reason TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
    risk_score NUMERIC(5,2) CHECK (risk_score IS NULL OR (
        risk_score >= 0 AND risk_score <= 100
    )),
    manual_review_required BOOLEAN NOT NULL DEFAULT FALSE,
    flagged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    UNIQUE (user_id, source, reason)
);

CREATE TABLE fraud_signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alert_id UUID REFERENCES fraud_alerts(id) ON DELETE CASCADE,
    booking_id UUID REFERENCES lesson_bookings(id) ON DELETE SET NULL,
    payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,
    signal_type TEXT NOT NULL,
    signal_value TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (metadata IS NOT NULL)
);

CREATE TABLE lesson_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES lesson_bookings(id) ON DELETE CASCADE,
    previous_status TEXT,
    new_status TEXT NOT NULL,
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

CREATE TABLE audit_log_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    subject_type TEXT NOT NULL,
    subject_id UUID,
    action TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address INET,
    metadata JSONB DEFAULT '{}',
    CHECK (metadata IS NOT NULL)
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

CREATE INDEX idx_data_erasure_status ON data_erasure_requests(status);

CREATE TABLE data_export_requests (
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
    export_location TEXT,
    notes TEXT,
    CHECK (
        processed_at IS NULL
        OR processed_at >= requested_at
    )
);

CREATE INDEX idx_data_export_status ON data_export_requests(status);

CREATE TABLE gdpr_processors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    service_description TEXT,
    dpa_executed BOOLEAN NOT NULL DEFAULT FALSE,
    eu_region_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    data_center_regions TEXT[],
    contact_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (name)
);

CREATE TABLE records_of_processing_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    processor_id UUID REFERENCES gdpr_processors(id) ON DELETE SET NULL,
    purpose TEXT NOT NULL,
    legal_basis TEXT NOT NULL,
    data_categories TEXT[] NOT NULL,
    data_subjects TEXT[] NOT NULL,
    retention_period TEXT,
    last_reviewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE gdpr_audit_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    happened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actor TEXT,
    details JSONB DEFAULT '{}',
    CHECK (details IS NOT NULL)
);

CREATE VIEW recent_chat_messages AS
SELECT
    cm.id,
    cm.thread_id,
    cm.sender_id,
    cm.body,
    cm.sent_at,
    cm.metadata
FROM chat_messages cm
WHERE cm.sent_at > NOW() - INTERVAL '48 hours'
ORDER BY cm.sent_at DESC;

-- Quick view to list upcoming confirmed bookings with the relevant student details.
CREATE VIEW upcoming_lessons AS
SELECT
    b.id,
    b.scheduled_start,
    b.duration_minutes,
    b.status,
    b.is_intro_session,
    b.meeting_link,
    b.jitsi_domain,
    b.meeting_room_name,
    b.manual_review_required,
    s.full_name AS student_name,
    sp.proficiency_level,
    sp.learning_goal,
    tp.jitsi_display_name AS tutor_display_name,
    tp.default_session_minutes,
    tp.booking_increment_minutes
FROM lesson_bookings b
JOIN users s ON b.student_id = s.id
JOIN student_profiles sp ON sp.user_id = s.id
JOIN tutor_profiles tp ON tp.user_id = b.tutor_id
WHERE b.status IN ('confirmed', 'requested')
ORDER BY b.scheduled_start;
