import Link from "next/link";

export default function MarketingPage() {
  return (
    <div className="flex flex-col gap-8">
      <section className="card">
        <h2 className="text-xl font-semibold text-white">Built for EU tutoring teams</h2>
        <p className="mt-2 text-sm text-slate-300">
          BookLessons pairs a modern booking funnel with privacy-forward infrastructure. Tutors
          can share availability, accept bookings, and message students — all from one secure hub.
        </p>
        <div className="mt-6 flex flex-wrap gap-4 text-sm text-slate-200">
          <div className="badge badge-success">GDPR ready</div>
          <div className="badge badge-warning">SCA payments</div>
          <div className="badge badge-success">EU data residency</div>
        </div>
        <div className="mt-8 flex flex-wrap gap-3">
          <Link
            className="rounded-full bg-amber-400 px-6 py-2 text-sm font-semibold text-slate-950 transition hover:bg-amber-300"
            href="/dashboard/bookings"
          >
            Go to dashboard
          </Link>
          <Link
            className="rounded-full border border-amber-300 px-6 py-2 text-sm font-semibold text-amber-300 transition hover:bg-amber-300/10"
            href="/privacy"
          >
            Review privacy policy
          </Link>
        </div>
      </section>
      <section className="card">
        <h3 className="text-lg font-medium text-white">Operational highlights</h3>
        <ul className="mt-4 grid gap-3 text-sm text-slate-300 md:grid-cols-2">
          <li>Next.js App Router deployed to Vercel in EU regions.</li>
          <li>Auth.js secure sessions backed by HttpOnly cookies.</li>
          <li>Stripe payments and webhook relay for booking lifecycle.</li>
          <li>SSE chat updates for fast tutor ↔ student collaboration.</li>
          <li>Automated fraud signals with manual review workflows.</li>
          <li>GDPR exports/erasures orchestrated from the dashboard.</li>
        </ul>
      </section>
    </div>
  );
}
