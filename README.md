# BookLessons

Database migrations for a Japanese tutoring application. The scripts in the
`db/` folder provision a streamlined schema that still covers the pieces a solo
tutor needs to run the business:

- unified user management for tutors and students
- calendar-style availability windows (including overrides) so learners can
  reserve specific minutes the tutor opens up
- lesson bookings with optional introductory/free minutes that can be toggled
  per tutor
- payments, outstanding debt tracking, and lightweight fraud alerts to monitor
  risky behaviour
- opt-in records and erasure request tracking to keep the workflow GDPR aware
- lesson notes and study materials tied to each booking

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

## GDPR-friendly defaults

- Only the minimal personal data (name, email, timezone) is stored in `users`.
- `privacy_consents` logs which policies a learner or tutor agreed to and when
  they withdrew consent.
- `data_erasure_requests` gives a simple audit trail for exports/anonymisation
  so you can demonstrate compliance during reviews.
- `marketing_opt_in` on the `users` table keeps promotional messaging separate
  from transactional communications.
