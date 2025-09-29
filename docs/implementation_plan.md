# Implementation Plan: BookLessons Platform Enhancements

This plan maps the product requirements to concrete implementation steps across the existing stack:
- **Student-facing Next.js App Router front-end on Vercel Hobby (EU regions)**
- **Tutor operations console built with Blazor Server on .NET 9 (Azure Web App in EU regions)**
- **Postgres (Neon) database provisioned via the migrations in `db/`**

Each section references the tables, views, and columns already present in the schema so the work stays aligned with the data model.

## 1. Frontend Hosting & SSR (Next.js on Vercel)

1. Add a `vercel.json` with EU-pinned regions:
   ```json
   {
     "regions": ["fra1", "cdg1"],
     "functions": {
       "api/**/*": {
         "regions": ["fra1", "cdg1"]
       }
     }
   }
   ```
2. Configure the project settings in Vercel to use the Hobby plan (free) and select **Europe** for the default region.
3. Use `NEXTAUTH_URL`, `DATABASE_URL`, `STRIPE_SECRET_KEY`, and `STRIPE_WEBHOOK_SECRET` environment variables with Vercel **Environment Variables** scoped to Production/Preview.
4. Serve SEO-sensitive pages (tutor profiles, lesson landing pages) through the App Router with streaming SSR. Hydrate availability data by querying:
   - `tutor_profiles`
   - `tutor_availability_patterns`
   - `tutor_availability_overrides`
   - `upcoming_lessons` view
5. Add `robots.txt` and `sitemap.xml` routes via the App Router for discoverability.

## 2. Authentication (Auth.js / NextAuth)

1. Use the official Auth.js Postgres adapter pointing to the Neon database. It maps to:
   - `users`
   - `auth_identities`
   - `user_sessions`
2. Implement email/passwordless sign-in or OAuth providers. Persist provider metadata in `auth_identities.provider` and `provider_account_id`.
3. Forward `auth_provider_id` and `last_sign_in_ip` into the `users` table for audit context.
4. Enable multi-factor prompts in the Blazor console for tutors by storing backup codes in a new table if needed (future migration).
5. Use the `marketing_opt_in` flag from `users` when deciding whether to show consent prompts inside Next.js.

## 3. Payments (Stripe)

1. Create Stripe customers and persist IDs in `users.stripe_customer_id`.
2. For each booking (`lesson_bookings`):
   - Create a PaymentIntent keyed by `lesson_bookings.id`.
   - Store the intent and charge IDs in `payments.intent_id` / `payments.charge_id`.
   - Record webhook events in `payment_events` with raw payload JSON for traceability.
3. Track outstanding balances in `student_debts`. Clear entries when a payment succeeds.
4. Link to Stripe's own DSAR/Privacy Center from GDPR request confirmations.
5. Expose a `POST /api/stripe/webhook` route in Next.js with a regional pin (EU) and signature verification.

## 4. Chat Functionality (Tutor ↔ Student)

1. Use `chat_threads` keyed by tutor/student pairs (`thread_type = 'one_to_one'`).
2. Persist messages in `chat_messages` with metadata (attachments, delivery hints) and track read receipts in `chat_message_receipts`.
3. Implement a Server-Sent Events route `/api/chat/sse` that queries the `recent_chat_messages` view every few seconds. Deploy as an Edge Function or Node function pinned to EU regions. The route should:
   - Accept a `threadId` query parameter.
   - Poll for new messages using `sent_at` and `id` cursors.
   - Emit events with message IDs, sender IDs, and body.
4. The Blazor dashboard can subscribe to the same SSE endpoint via HttpClient streaming for near-real-time updates.

## 5. Fraud Detection & Manual Review

1. Populate `fraud_signals` whenever Stripe metadata flags issues (rapid cancelations, IP/card mismatch). Example payload:
   ```json
   {
     "source": "stripe",
     "signal_type": "ip_card_mismatch",
     "evidence": {"ip_country": "DE", "card_country": "JP"}
   }
   ```
2. Compute a risk score per booking and persist it in `lesson_bookings.fraud_risk_score`.
3. Set `lesson_bookings.manual_review_required = TRUE` when scores cross a threshold or if `fraud_signals.requires_manual_review` is true.
4. Create `fraud_alerts` entries summarizing the risk. Reference relevant payment IDs for cross-checking.
5. Surface manual review queues in the Blazor console: query `fraud_alerts` joined with `lesson_bookings` (status `requested`/`pending_review`).

## 6. GDPR Compliance

1. Execute DPAs and document processors by seeding `gdpr_processors` with rows for Vercel, Stripe, and Jitsi (if using meet.jit.si). Mark `dpa_executed` and `eu_region_pinned` booleans accordingly.
2. Maintain `records_of_processing_activities` with purposes (lesson delivery, payments, chat support) and legal bases (contract, legitimate interest, consent).
3. Implement Next.js API routes for data subject rights:
   - `POST /api/gdpr/export` → inserts into `data_export_requests`.
   - `POST /api/gdpr/erase` → inserts into `data_erasure_requests`.
   - Update status via Blazor console workflows; store audit steps in `gdpr_audit_events` and `audit_log_entries`.
4. Provide download links using pre-signed Azure Blob (for tutor exports) or Vercel storage depending on deployment.
5. Add privacy policy and legal notices pages describing controller/processor roles, SCCs, and data flows.

## 7. Live Lessons via Jitsi

1. Generate deterministic meeting rooms using `lesson_bookings.meeting_room_name` (e.g., `tutor{tutorId}_booking{bookingId}`).
2. Store the domain (`lesson_bookings.jitsi_domain`) defaulting to `meet.jit.si`.
3. On the Next.js lesson detail page:
   - Show a **Join** button when `status = 'confirmed'` and `manual_review_required = FALSE`.
   - Embed the Jitsi IFrame API using the stored room name.
   - Display fallback instructions (Google Meet creation) if participants report NAT/firewall problems.
4. Log join attempts in `lesson_status_history` and `audit_log_entries` for accountability.

## 8. Data Minimisation & Security Controls

1. Only request necessary profile information (languages, goals). Avoid storing raw payment card data (Stripe handles this).
2. Enforce TLS connections to Neon using connection string parameters (`sslmode=require`).
3. Rotate credentials and secrets through:
   - Vercel environment variables (front-end SSR/API).
   - Azure Key Vault (Blazor server, background jobs).
4. Schedule periodic cleanup jobs using Azure Functions or Vercel Cron to anonymise users with `data_retention_expires_at < NOW()`.
5. Use `gdpr_audit_events` and `audit_log_entries` to maintain an audit trail for exports, erasures, and fraud reviews.

## 9. Operational Checklist

- [ ] Verify Vercel ↔ Neon connection works from EU regions with low latency.
- [ ] Configure Stripe webhooks to hit the EU-hosted Next.js endpoint.
- [ ] Document the executed DPAs and attach them to `gdpr_processors` entries.
- [ ] Provide a user-facing privacy policy detailing legal bases and processor roles.
- [ ] Test SSE chat updates under load to confirm Vercel Hobby limits are not exceeded.
- [ ] Validate Jitsi room naming collisions do not occur by using UUID-based suffixes if necessary.
- [ ] Establish manual-review runbook for fraud alerts via the Blazor dashboard.
- [ ] Keep an audit log of all admin actions touching personal data.

