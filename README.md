# BookLessons

Database migrations for a Japanese tutoring application that pairs a Blazor
Server operations console (.NET 9 on Azure Web App) with a student-facing
Next.js (App Router) experience deployed on the Vercel Hobby tier in EU
regions. The scripts in the `db/` folder provision a streamlined schema that
still covers the pieces a solo tutor needs to run the business while meeting
the latest product requirements:

- unified user management for tutors and students, including Auth.js compatible
  identity/session tables
- calendar-style availability windows (including overrides and buffer minutes)
  so learners can reserve specific minutes the tutor opens up
- lesson bookings with optional introductory/free minutes that can be toggled
  per tutor and deterministic Jitsi room names for confirmed sessions
- payments powered by Stripe, outstanding debt tracking, and enhanced fraud
  signals with manual-review support
- 1:1 tutor↔student chat threads that feed a free Server-Sent Event (SSE) route
  for live updates on Vercel Hobby
- opt-in records, processors/DPA tracking, export/erasure request tables, and
  audit trails to operationalise GDPR compliance in EU regions
- lesson notes, materials, and study artefacts tailored to Japanese tutoring

## Getting started on Neon (free Postgres)

1. Create a new Neon project and database (the default Postgres 15 branch
   works out of the box).
2. Copy the connection string from the Neon dashboard and feed it into `psql`:

   ```bash
   psql "postgresql://<user>:<password>@<host>/<database>"
   ```

3. Run the migration files in order:

   ```bash
   \i db/001_create_extensions.sql
   \i db/schema.sql
   \i db/002_seed_data.sql
   ```

4. (Optional) reconnect with a limited role for your Blazor Server app once the
   structure is in place.

## Stack & hosting configuration

- **Next.js on Vercel Hobby (EU regions):** Deploy the App Router front-end with
  `regions: ['fra1', 'cdg1']` in `vercel.json` so all SSR/API work stays in the
  EU. Use the free SSE route to stream updates from the `recent_chat_messages`
  view—polling every few seconds keeps the Hobby tier happy while still feeling
  near-real-time.
- **Auth.js / NextAuth:** The `auth_identities` and `user_sessions` tables map
  directly to Auth.js adapter expectations. Store session tokens with short
  expiries and rotate refresh tokens in the Blazor admin when tutors revoke
  access.
- **Stripe payments:** `payments` stores intent and charge identifiers; the
  accompanying `payment_events` table is ready for webhook persistence within a
  Vercel function (remember to keep the function in an EU region as well).
- **Video calls via Jitsi:** `lesson_bookings.meeting_room_name` deterministically
  combines the tutor and booking IDs. Embed a Jitsi IFrame when status is
  `confirmed`, falling back to a Google Meet hint if participants report NAT
  issues.
- **Azure Web App + Blazor Server:** The tutor dashboard can reuse the same Neon
  connection string with an app setting scoped to the Azure Europe regions.

## Key tables & how they map to features

| Capability | Tables / Views | Notes |
| --- | --- | --- |
| Availability & calendar | `tutor_availability_patterns`, `tutor_availability_overrides`, `tutor_profiles` | Supports buffer minutes, intro eligibility, and timezone overrides. |
| Bookings & intro minutes | `lesson_bookings`, `lesson_status_history` | Track manual review, fraud scores, and deterministic Jitsi room names. |
| Payments & debt | `payments`, `payment_events`, `student_debts` | Stripe intent + charge IDs plus JSONB metadata for fraud review. |
| Fraud detection | `fraud_alerts`, `fraud_signals`, `audit_log_entries` | Captures risk scores, manual-review flags, and detailed signal payloads. |
| Chat & live updates | `chat_threads`, `chat_messages`, `chat_message_receipts`, `recent_chat_messages` | Works with an SSE polling route on Vercel for near-real-time messaging. |
| GDPR lifecycle | `privacy_consents`, `data_export_requests`, `data_erasure_requests`, `gdpr_processors`, `records_of_processing_activities`, `gdpr_audit_events` | Keep processors, DPAs, and user requests auditable. |
| Learning materials | `lesson_notes`, `study_materials`, `lesson_materials` | Store Japanese study artefacts per session. |

## GDPR operations checklist

- **Data minimisation:** `users` only stores core contact info plus optional
  Stripe/Auth identifiers. Use `data_retention_expires_at` to drive periodic
  clean-up jobs.
- **Consent & lawful basis tracking:** `privacy_consents` records opt-ins; the
  Blazor console should reference this before sending marketing emails. Link to
  Stripe's [privacy center](https://support.stripe.com/contact/privacy) when
  acknowledging requests that involve Stripe-hosted data.
- **Data subject rights:**
  - Export requests flow through `data_export_requests` (use Azure Blob SAS
    links for delivery).
  - Erasure/anonymisation status lives in `data_erasure_requests` and
    `users.anonymized_at`.
  - `gdpr_audit_events` and `audit_log_entries` capture who did what, when.
- **Processors & DPAs:** Populate `gdpr_processors` with Vercel, Stripe, and
  Jitsi (if meet.jit.si is used). Mark `dpa_executed` once contracts are
  signed, and note EU-pinned regions.
- **Security controls:** Pin all Vercel functions to EU, enforce TLS when
  calling Neon, and rely on Azure-managed identity/Key Vault for the Blazor
  connection string.

## Deterministic Jitsi rooms & free intro minutes

- Tutors set `intro_offer_minutes` and toggle availability with
  `intro_offer_enabled`; student profiles track redemptions to prevent abuse.
- The generated `lesson_bookings.meeting_room_name` is stable and deterministic
  (`tutor<tutorId>_booking<bookingId>`), making it safe to rehydrate the Jitsi
  IFrame after a reconnect.
- Use `manual_review_required` and `fraud_risk_score` to decide whether to show
  the join link immediately or hold the booking until the tutor clears it in
  the Blazor dashboard.

## Implementation blueprint

See [`docs/system_architecture.md`](docs/system_architecture.md) for a detailed
plan that ties the database schema to the Next.js (App Router) frontend on
Vercel Hobby, the Blazor Server operations console on Azure, Auth.js sessions,
Stripe payment flows, SSE chat streaming, deterministic Jitsi rooms, and GDPR
process operations. The document includes recommended configuration snippets,
API route outlines, and operational checklists for EU-hosted deployments.
