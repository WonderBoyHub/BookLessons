-- Sample data for local development of the Japanese tutoring app
-- The inserts assume schema.sql has already been executed.

-- Users
INSERT INTO users (
    role,
    full_name,
    email,
    timezone,
    marketing_opt_in,
    country_code,
    stripe_customer_id,
    auth_provider_id,
    data_retention_expires_at
)
VALUES
    (
        'tutor',
        'Yumi Nakamura',
        'yumi@example.com',
        'Asia/Tokyo',
        TRUE,
        'JP',
        'cus_JP_TUTOR_001',
        'email:yumi@example.com',
        NOW() + INTERVAL '3 years'
    ),
    (
        'student',
        'Alex Johnson',
        'alex@example.com',
        'America/Los_Angeles',
        FALSE,
        'US',
        'cus_US_STUDENT_001',
        'email:alex@example.com',
        NOW() + INTERVAL '2 years'
    ),
    (
        'student',
        'Maria Lopez',
        'maria@example.com',
        'Europe/Madrid',
        FALSE,
        'ES',
        NULL,
        'email:maria@example.com',
        NOW() + INTERVAL '2 years'
    )
ON CONFLICT (email) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    marketing_opt_in = EXCLUDED.marketing_opt_in,
    country_code = EXCLUDED.country_code,
    data_retention_expires_at = EXCLUDED.data_retention_expires_at;

INSERT INTO auth_identities (user_id, provider, provider_account_id, scopes)
SELECT id, provider, provider_account_id, scopes
FROM (
    VALUES
        ('yumi@example.com', 'email', 'yumi@example.com', ARRAY['profile', 'email']),
        ('alex@example.com', 'email', 'alex@example.com', ARRAY['profile', 'email']),
        ('maria@example.com', 'email', 'maria@example.com', ARRAY['profile', 'email'])
) AS identity(email, provider, provider_account_id, scopes)
JOIN users ON users.email = identity.email
ON CONFLICT (provider, provider_account_id) DO NOTHING;

INSERT INTO user_sessions (
    user_id,
    session_token,
    expires_at,
    ip_address,
    user_agent
)
SELECT
    id,
    concat('session_', replace(id::TEXT, '-', '')),
    NOW() + INTERVAL '7 days',
    '203.0.113.10',
    'Next.js SSR agent'
FROM users
WHERE email = 'alex@example.com'
ON CONFLICT (session_token) DO NOTHING;

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
    calendar_timezone,
    notification_email,
    jitsi_display_name,
    availability_buffer_minutes
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
    'Asia/Tokyo',
    'yumi+tutor@example.com',
    '中村 由美 (Yumi)',
    10
FROM users
WHERE email = 'yumi@example.com'
ON CONFLICT (user_id) DO UPDATE SET
    introduction = EXCLUDED.introduction,
    hourly_rate = EXCLUDED.hourly_rate,
    jitsi_display_name = EXCLUDED.jitsi_display_name,
    availability_buffer_minutes = EXCLUDED.availability_buffer_minutes;

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
    price_per_minute,
    stripe_payment_intent_id,
    manual_review_required
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
        1.80,
        'pi_intro_1',
        FALSE
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
        1.80,
        'pi_request_1',
        TRUE
    )
ON CONFLICT (tutor_id, student_id, scheduled_start) DO NOTHING;

UPDATE lesson_bookings
SET fraud_risk_score = 68.2
WHERE stripe_payment_intent_id = 'pi_request_1';

INSERT INTO lesson_status_history (
    booking_id,
    previous_status,
    new_status,
    changed_by,
    notes
)
SELECT
    id,
    NULL,
    status,
    tutor_id,
    CASE WHEN is_intro_session THEN 'Auto-confirmed intro welcome call'
        ELSE 'Awaiting manual review due to high-risk signals'
    END
FROM lesson_bookings
ON CONFLICT DO NOTHING;

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

-- Chat thread seeded for tutor and Alex
INSERT INTO chat_threads (tutor_id, student_id, last_message_at)
VALUES (
    (SELECT id FROM users WHERE email = 'yumi@example.com'),
    (SELECT id FROM users WHERE email = 'alex@example.com'),
    NOW() - INTERVAL '10 minutes'
)
ON CONFLICT (tutor_id, student_id) DO NOTHING;

WITH thread AS (
    SELECT id FROM chat_threads
    WHERE tutor_id = (SELECT id FROM users WHERE email = 'yumi@example.com')
      AND student_id = (SELECT id FROM users WHERE email = 'alex@example.com')
)
INSERT INTO chat_messages (thread_id, sender_id, body, metadata)
SELECT
    thread.id,
    sender.id,
    message,
    metadata
FROM (
    VALUES
        ('yumi@example.com', 'こんにちは！明日の体験レッスン楽しみにしています。', '{"lang":"ja"}'::JSONB),
        ('alex@example.com', 'Thank you! I''ll prepare some questions about keigo.', '{"lang":"en"}'::JSONB)
) AS msg(email, message, metadata)
JOIN users sender ON sender.email = msg.email,
thread
ON CONFLICT DO NOTHING;

INSERT INTO chat_message_receipts (message_id, user_id, receipt_type)
SELECT
    cm.id,
    users.id,
    'delivered'
FROM chat_messages cm
JOIN chat_threads ct ON cm.thread_id = ct.id
JOIN users ON users.id = ct.student_id
WHERE cm.sender_id <> users.id
ON CONFLICT DO NOTHING;

UPDATE chat_threads
SET last_message_at = sub.max_sent
FROM (
    SELECT thread_id, MAX(sent_at) AS max_sent
    FROM chat_messages
    GROUP BY thread_id
) AS sub
WHERE chat_threads.id = sub.thread_id;

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
    paid_at,
    stripe_charge_id,
    stripe_payment_intent_id,
    billing_country,
    card_country,
    billing_ip,
    metadata
)
VALUES (
    (SELECT id FROM lesson_bookings WHERE is_intro_session = TRUE LIMIT 1),
    (SELECT id FROM users WHERE email = 'yumi@example.com'),
    (SELECT id FROM users WHERE email = 'alex@example.com'),
    9000.00,
    'JPY',
    'captured',
    'Stripe',
    'pi_intro_1',
    NOW(),
    'ch_intro_1',
    'pi_intro_1',
    'JP',
    'US',
    '198.51.100.24',
    '{"card_brand":"visa","ip_card_mismatch":true}'::JSONB
)
ON CONFLICT (provider, provider_reference) DO NOTHING;

INSERT INTO payment_events (payment_id, event_type, payload)
SELECT
    id,
    'payment_intent.succeeded',
    '{"source":"stripe","amount":9000}'::JSONB
FROM payments
WHERE stripe_payment_intent_id = 'pi_intro_1'
ON CONFLICT DO NOTHING;

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
INSERT INTO fraud_alerts (user_id, source, reason, severity, risk_score, manual_review_required)
VALUES (
    (SELECT id FROM users WHERE email = 'alex@example.com'),
    'payment_gateway',
    'Multiple charge attempts within one minute.',
    'low',
    32.5,
    TRUE
)
ON CONFLICT (user_id, source, reason) DO NOTHING;

INSERT INTO fraud_signals (
    alert_id,
    booking_id,
    payment_id,
    signal_type,
    signal_value,
    metadata
)
SELECT
    alert.id,
    (SELECT id FROM lesson_bookings WHERE stripe_payment_intent_id = 'pi_intro_1'),
    (SELECT id FROM payments WHERE stripe_payment_intent_id = 'pi_intro_1'),
    'ip_card_country_mismatch',
    'US vs JP',
    '{"stripe_ip":"198.51.100.24","card_country":"US","billing_country":"JP"}'::JSONB
FROM fraud_alerts alert
WHERE alert.reason = 'Multiple charge attempts within one minute.'
ON CONFLICT DO NOTHING;

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

INSERT INTO data_export_requests (user_id, requested_at, status, processed_at, export_location, notes)
VALUES (
    (SELECT id FROM users WHERE email = 'alex@example.com'),
    NOW() - INTERVAL '1 day',
    'completed',
    NOW() - INTERVAL '12 hours',
    'azure://gdpr-exports/alex-2024-05-01.zip',
    'Shared encrypted archive via time-limited link.'
)
ON CONFLICT DO NOTHING;

INSERT INTO gdpr_processors (
    name,
    service_description,
    dpa_executed,
    eu_region_pinned,
    data_center_regions,
    contact_url
)
VALUES
    (
        'Vercel',
        'Frontend hosting for the Next.js marketing and booking experience.',
        TRUE,
        TRUE,
        ARRAY['Frankfurt', 'Paris'],
        'https://vercel.com/legal/dpa'
    ),
    (
        'Stripe',
        'Payment processing and fraud insights.',
        TRUE,
        TRUE,
        ARRAY['Dublin', 'Frankfurt'],
        'https://stripe.com/legal/dpa'
    ),
    (
        'Jitsi',
        'Video lessons via meet.jit.si bridge.',
        TRUE,
        FALSE,
        ARRAY['Frankfurt', 'United States'],
        'https://jitsi.org/security/'
    )
ON CONFLICT (name) DO UPDATE SET
    dpa_executed = EXCLUDED.dpa_executed,
    eu_region_pinned = EXCLUDED.eu_region_pinned;

INSERT INTO records_of_processing_activities (
    processor_id,
    purpose,
    legal_basis,
    data_categories,
    data_subjects,
    retention_period
)
SELECT
    id,
    purpose,
    legal_basis,
    data_categories,
    data_subjects,
    retention
FROM (
    VALUES
        (
            'Vercel',
            'Serve SSR pages and API routes for bookings.',
            'Art. 6(1)(b) GDPR - contract',
            ARRAY['name', 'email', 'lesson preference'],
            ARRAY['students', 'tutors'],
            'Logs retained 30 days'
        ),
        (
            'Stripe',
            'Collect lesson payments and detect fraud.',
            'Art. 6(1)(c) GDPR - legal obligation',
            ARRAY['payment method token', 'billing country', 'fraud signals'],
            ARRAY['students'],
            '7 years'
        ),
        (
            'Jitsi',
            'Host live video rooms.',
            'Art. 6(1)(b) GDPR - contract',
            ARRAY['display name'],
            ARRAY['students', 'tutors'],
            'Ephemeral'
        )
) AS rop(name, purpose, legal_basis, data_categories, data_subjects, retention)
JOIN gdpr_processors gp ON gp.name = rop.name
ON CONFLICT DO NOTHING;

INSERT INTO gdpr_audit_events (user_id, event_type, actor, details)
VALUES (
    (SELECT id FROM users WHERE email = 'alex@example.com'),
    'consent_withdrawn',
    'system',
    '{"consent_type":"marketing_emails","processed_by":"Blazor backend"}'::JSONB
)
ON CONFLICT DO NOTHING;

INSERT INTO audit_log_entries (
    actor_id,
    subject_type,
    subject_id,
    action,
    ip_address,
    metadata
)
VALUES (
    (SELECT id FROM users WHERE email = 'yumi@example.com'),
    'lesson_booking',
    (SELECT id FROM lesson_bookings WHERE stripe_payment_intent_id = 'pi_request_1'),
    'manual_review_flagged',
    '203.0.113.44',
    '{"reason":"High-risk stripe signal","requires_follow_up":true}'::JSONB
)
ON CONFLICT DO NOTHING;
