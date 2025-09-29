-- Sample data for local development of the Japanese tutoring app
-- The inserts assume schema.sql has already been executed.

-- Users
INSERT INTO users (role, full_name, email, timezone, marketing_opt_in)
VALUES
    ('tutor', 'Yumi Nakamura', 'yumi@example.com', 'Asia/Tokyo', TRUE),
    ('student', 'Alex Johnson', 'alex@example.com', 'America/Los_Angeles', FALSE),
    ('student', 'Maria Lopez', 'maria@example.com', 'Europe/Madrid', FALSE)
ON CONFLICT (email) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    marketing_opt_in = EXCLUDED.marketing_opt_in;

-- Tutor profile and availability
INSERT INTO tutor_profiles (
    user_id,
    introduction,
    teaching_languages,
    hourly_rate,
    intro_offer_minutes,
    intro_offer_enabled,
    default_session_minutes,
    booking_increment_minutes,
    max_daily_minutes,
    calendar_timezone
)
SELECT
    id,
    'Native Japanese tutor focusing on conversational fluency and JLPT preparation.',
    ARRAY['Japanese', 'English'],
    45.00,
    20,
    TRUE,
    50,
    25,
    240,
    'Asia/Tokyo'
FROM users
WHERE email = 'yumi@example.com'
ON CONFLICT (user_id) DO UPDATE SET
    introduction = EXCLUDED.introduction,
    hourly_rate = EXCLUDED.hourly_rate;

INSERT INTO tutor_availability_patterns (
    tutor_id,
    weekday,
    start_time,
    end_time,
    slot_minutes,
    allow_intro_sessions,
    notes
)
SELECT
    id,
    weekday,
    start_time,
    end_time,
    slot_minutes,
    allow_intro,
    note
FROM (
    VALUES
        ( (SELECT id FROM users WHERE email = 'yumi@example.com'), 1, TIME '18:00', TIME '21:00', 25, TRUE, 'Weekday evening availability' ),
        ( (SELECT id FROM users WHERE email = 'yumi@example.com'), 6, TIME '09:00', TIME '12:00', 50, TRUE, 'Saturday morning intensives' )
) AS availability(id, weekday, start_time, end_time, slot_minutes, allow_intro, note)
ON CONFLICT (tutor_id, weekday, start_time, end_time) DO NOTHING;

INSERT INTO tutor_availability_overrides (
    tutor_id,
    start_at,
    end_at,
    available_minutes,
    override_type,
    notes
)
VALUES (
    (SELECT id FROM users WHERE email = 'yumi@example.com'),
    NOW() + INTERVAL '7 days',
    NOW() + INTERVAL '7 days 2 hours',
    120,
    'extra_time',
    'Open extra slots for JLPT crunch time'
)
ON CONFLICT (tutor_id, start_at, end_at) DO NOTHING;

-- Students
INSERT INTO student_profiles (
    user_id,
    proficiency_level,
    learning_goal,
    preferred_topics,
    intro_minutes_redeemed,
    joined_via_referral
)
SELECT
    id,
    level,
    goal,
    topics,
    redeemed,
    referral
FROM (
    VALUES
        ( (SELECT id FROM users WHERE email = 'alex@example.com'), 'intermediate', 'Pass JLPT N3 this year.', ARRAY['JLPT preparation', 'Conversation'], 0, TRUE ),
        ( (SELECT id FROM users WHERE email = 'maria@example.com'), 'beginner', 'Build confidence with everyday conversation.', ARRAY['Travel', 'Culture'], 0, FALSE )
) AS student_data(id, level, goal, topics, redeemed, referral)
ON CONFLICT (user_id) DO UPDATE SET
    proficiency_level = EXCLUDED.proficiency_level,
    learning_goal = EXCLUDED.learning_goal;

-- Lesson bookings
INSERT INTO lesson_bookings (
    tutor_id,
    student_id,
    scheduled_start,
    duration_minutes,
    status,
    is_intro_session,
    intro_minutes_applied,
    meeting_link,
    price_per_minute
)
VALUES
    (
        (SELECT id FROM users WHERE email = 'yumi@example.com'),
        (SELECT id FROM users WHERE email = 'alex@example.com'),
        NOW() + INTERVAL '1 day',
        50,
        'confirmed',
        TRUE,
        20,
        'https://meet.example.com/intro-japanese',
        1.80
    ),
    (
        (SELECT id FROM users WHERE email = 'yumi@example.com'),
        (SELECT id FROM users WHERE email = 'maria@example.com'),
        NOW() + INTERVAL '3 days',
        75,
        'requested',
        FALSE,
        0,
        'https://meet.example.com/japanese-lesson',
        1.80
    )
ON CONFLICT (tutor_id, student_id, scheduled_start) DO NOTHING;

-- Lesson notes & materials for confirmed booking
INSERT INTO lesson_notes (booking_id, summary, homework, vocabulary, next_focus)
SELECT
    id,
    'Covered polite introductions and scheduling vocabulary.',
    'Practice self-introduction script for 5 minutes daily.',
    ARRAY['はじめまして', 'よろしくお願いします'],
    'Casual conversation fillers'
FROM lesson_bookings
WHERE is_intro_session = TRUE
ON CONFLICT (booking_id) DO UPDATE SET
    summary = EXCLUDED.summary,
    homework = EXCLUDED.homework,
    vocabulary = EXCLUDED.vocabulary,
    next_focus = EXCLUDED.next_focus;

INSERT INTO study_materials (tutor_id, title, description, resource_url, tags)
VALUES (
    (SELECT id FROM users WHERE email = 'yumi@example.com'),
    'JLPT N3 Listening Set',
    'Audio drills for transit announcements and daily conversations.',
    'https://example.com/materials/jlpt-n3-listening',
    ARRAY['JLPT', 'Listening']
)
ON CONFLICT (tutor_id, title) DO UPDATE SET
    description = EXCLUDED.description,
    resource_url = EXCLUDED.resource_url,
    tags = EXCLUDED.tags;

INSERT INTO lesson_materials (booking_id, material_id)
SELECT
    (SELECT id FROM lesson_bookings WHERE is_intro_session = TRUE LIMIT 1),
    id
FROM study_materials
WHERE title = 'JLPT N3 Listening Set'
ON CONFLICT DO NOTHING;

-- Payments & debt tracking
INSERT INTO payments (
    booking_id,
    tutor_id,
    student_id,
    amount,
    currency,
    status,
    provider,
    provider_reference,
    paid_at
)
VALUES (
    (SELECT id FROM lesson_bookings WHERE is_intro_session = TRUE LIMIT 1),
    (SELECT id FROM users WHERE email = 'yumi@example.com'),
    (SELECT id FROM users WHERE email = 'alex@example.com'),
    9000.00,
    'JPY',
    'captured',
    'Stripe',
    'pi_123456789',
    NOW()
)
ON CONFLICT (provider, provider_reference) DO NOTHING;

INSERT INTO student_debts (
    student_id,
    tutor_id,
    booking_id,
    amount_due,
    due_date,
    status,
    notes
)
VALUES (
    (SELECT id FROM users WHERE email = 'maria@example.com'),
    (SELECT id FROM users WHERE email = 'yumi@example.com'),
    (SELECT id FROM lesson_bookings WHERE is_intro_session = FALSE LIMIT 1),
    13500.00,
    CURRENT_DATE + 10,
    'open',
    'Awaiting payment after rescheduling'
)
ON CONFLICT (student_id, tutor_id, booking_id) DO UPDATE SET
    amount_due = EXCLUDED.amount_due,
    due_date = EXCLUDED.due_date,
    status = EXCLUDED.status,
    notes = EXCLUDED.notes;

-- Fraud alert example for monitoring
INSERT INTO fraud_alerts (user_id, source, reason, severity)
VALUES (
    (SELECT id FROM users WHERE email = 'alex@example.com'),
    'payment_gateway',
    'Multiple charge attempts within one minute.',
    'low'
)
ON CONFLICT (user_id, source, reason) DO NOTHING;

-- GDPR helpers: capture consent and a sample erasure request workflow
INSERT INTO privacy_consents (user_id, consent_type, granted_at, notes)
SELECT id, consent_type, NOW() - interval '10 days', note
FROM (
    VALUES
        ('yumi@example.com', 'terms_of_service', 'Accepted updated policy v2.1'),
        ('yumi@example.com', 'marketing_emails', 'Opted in to monthly tips'),
        ('alex@example.com', 'terms_of_service', 'Accepted onboarding terms'),
        ('maria@example.com', 'terms_of_service', 'Accepted onboarding terms')
) AS consent_data(email, consent_type, note)
JOIN users ON users.email = consent_data.email
ON CONFLICT (user_id, consent_type, granted_at) DO NOTHING;

INSERT INTO data_erasure_requests (user_id, requested_at, status, processed_at, notes)
VALUES (
    (SELECT id FROM users WHERE email = 'maria@example.com'),
    NOW() - INTERVAL '2 days',
    'completed',
    NOW() - INTERVAL '1 day',
    'Exported vocabulary notes and anonymised marketing preferences.'
)
ON CONFLICT DO NOTHING;
