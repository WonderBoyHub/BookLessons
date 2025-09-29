# System architecture & implementation blueprint

This document maps the latest product requirements onto the existing Neon
Postgres schema in `db/` and outlines how to wire the components together across
the Blazor Server operations console (.NET 9 on Azure Web App) and the
student-facing Next.js (App Router) frontend deployed on Vercel Hobby in EU
regions.

## Hosting & infrastructure

### Database (Neon)
- Use the free Neon project as the single source of truth.
- Enable the `uuid-ossp` extension per `db/001_create_extensions.sql`.
- Create a dedicated role for the Blazor Server console with restricted
  privileges (`SELECT/INSERT/UPDATE` on operational tables, `SELECT` on views
  like `upcoming_lessons` and `recent_chat_messages`).
- Create a read/write role for the Next.js API routes so the web app can manage
  bookings, chat messages, and Auth.js sessions.

### Vercel configuration
- Deploy the Next.js App Router project to the Hobby tier with EU-only function
  regions. Add the following to `vercel.json`:

  ```json
  {
    "regions": ["fra1", "cdg1"],
    "functions": {
      "api/**": { "regions": ["fra1", "cdg1"] },
      "app/**": { "regions": ["fra1", "cdg1"] }
    }
  }
  ```

- Store the Neon connection string, Stripe keys, and Auth.js secrets in Vercel
  environment variables.
- Enable the [Data Processing Addendum](https://vercel.com/legal/dpa) in the
  Vercel dashboard and record the execution inside `gdpr_processors`.

### Azure Web App (Blazor Server)
- Host the tutor console in the Azure West Europe or North Europe region.
- Inject the Neon connection string via Azure App Settings or Key Vault backed
  by Managed Identity.
- Restrict outbound networking so only Neon, Stripe, and Vercel webhook
  endpoints are reachable.

## Authentication (Auth.js / NextAuth)
- Back Auth.js with the existing `users`, `auth_identities`, and `user_sessions`
  tables.
- Use the official Auth.js Prisma adapter or a custom Postgres adapter that maps
  providers to `auth_identities(provider, provider_account_id)` and sessions to
  `user_sessions`.
- Configure the Next.js `/app/api/auth/[...nextauth]/route.ts` with email +
  OAuth providers (e.g., Google) and mark `callbacks.session` to inject the
  `users.role` so the frontend can branch between student and tutor UX.
- When a session is revoked from the Blazor console, write to
  `user_sessions.last_seen_at` and delete stale rows for defense-in-depth.

## Payments & fraud detection (Stripe)
- Create PaymentIntents in the Next.js booking flow and persist the intent ID in
  `lesson_bookings.stripe_payment_intent_id` and `payments.stripe_payment_intent_id`.
- Implement a `/app/api/stripe/webhook/route.ts` endpoint to verify webhook
  signatures, update `payments.status`, and append structured events into
  `payment_events`.
- Extract fraud indicators (rapid cancellations, IP vs card country mismatch)
  and store them in `fraud_signals` with references to the relevant payment or
  booking. Flag suspicious bookings by setting `lesson_bookings.manual_review_required`
  and adjusting `fraud_risk_score`.
- Surface manual review queues in the Blazor console by filtering
  `lesson_bookings` where `manual_review_required = TRUE` or via the
  `fraud_alerts` table for user-level investigations.

## Chat and live updates (SSE)
- Use `chat_threads`, `chat_messages`, and `chat_message_receipts` to support the
  1:1 tutor↔student messaging requirements.
- Render the thread view in a Next.js server component and stream updates via a
  lightweight SSE route at `app/api/chat/stream/route.ts`:

  ```ts
  import { NextRequest } from 'next/server'
  import { pool } from '@/lib/db'

  export async function GET(req: NextRequest) {
    const encoder = new TextEncoder()
    const stream = new ReadableStream({
      async start(controller) {
        const sendBatch = async () => {
          const { rows } = await pool.query(
            'SELECT * FROM recent_chat_messages WHERE thread_id = $1 LIMIT 50',
            [req.nextUrl.searchParams.get('threadId')]
          )
          for (const row of rows) {
            controller.enqueue(
              encoder.encode(`id: ${row.id}\nevent: message\ndata: ${JSON.stringify(row)}\n\n`)
            )
          }
        }

        await sendBatch()
        const interval = setInterval(sendBatch, 4000)
        req.signal.addEventListener('abort', () => clearInterval(interval))
      },
    })

    return new Response(stream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
      },
    })
  }
  ```

- On the client, use the native `EventSource` API inside a `useEffect` hook and
  write incoming events into a React query cache or component state.

## Deterministic Jitsi meetings
- The computed column `lesson_bookings.meeting_room_name` already generates
  deterministic identifiers (`tutor<tutorId>_booking<bookingId>`).
- Add a Join button in the Next.js booking detail page only when
  `status = 'confirmed'` and either the `fraud_risk_score` is below a threshold
  or manual review is cleared.
- Embed the Jitsi IFrame API with the generated domain + room:

  ```ts
  const domain = booking.jitsi_domain ?? 'meet.jit.si'
  const roomName = booking.meeting_room_name
  const iframe = new JitsiMeetExternalAPI(domain, {
    roomName,
    parentNode: document.querySelector('#jitsi-container'),
    userInfo: { displayName: session.user.name },
  })
  ```

- Display a fallback alert instructing participants to create a Google Meet
  session if NAT traversal fails (per 8×8 fair-use guidance).

## GDPR operations
- Seed `gdpr_processors` with Vercel, Stripe, and Jitsi (if meet.jit.si is used).
  Include columns `dpa_executed = TRUE`, `eu_region_pinned = TRUE`, and a note
  about Standard Contractual Clauses when relevant.
- Publish a privacy policy page in Next.js describing controller/processor roles
  and referencing the SCCs for any third-country transfers carried out by your
  processors.
- Implement API routes to handle data subject rights:
  - `POST /app/api/gdpr/export` inserts into `data_export_requests` and queues a
    background job (Azure Function or Vercel Cron) to generate exports.
  - `POST /app/api/gdpr/erase` inserts into `data_erasure_requests`; the Blazor
    console surfaces these for operators to anonymize data and update
    `users.anonymized_at`.
- Provide links in the UI to Stripe's own [DSAR portal](https://support.stripe.com/contact/privacy)
  for payment data held by Stripe.
- Log administrative actions in `audit_log_entries` and `gdpr_audit_events` to
  keep a defensible trail.

## Data minimisation & security
- Store only required PII (`full_name`, `email`, `timezone`) and rely on Stripe
  for card data.
- Enforce TLS for all database connections; Neon provides certificates suitable
  for Azure and Vercel.
- Periodically clear stale chat messages or anonymize them after
  `data_retention_expires_at` via a background cleanup job.
- Validate incoming Stripe webhooks and Auth.js callbacks with signed secrets.
- Add monitoring for rapid cancellation patterns by querying
  `lesson_status_history` over short time windows and raising alerts via
  `fraud_alerts` if thresholds are exceeded.
