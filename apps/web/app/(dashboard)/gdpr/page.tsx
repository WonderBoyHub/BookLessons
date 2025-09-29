import { requestDataErasure, requestDataExport } from "@/lib/api";

async function queueExport() {
  "use server";
  await requestDataExport();
}

async function queueErasure() {
  "use server";
  await requestDataErasure();
}

export default function GdprPage() {
  return (
    <div className="card flex flex-col gap-4">
      <header>
        <h2 className="text-lg font-semibold text-white">GDPR Control Center</h2>
        <p className="text-xs text-slate-400">
          Trigger exports and erasures handled by the ASP.NET Core backend. Stripe data subject
          requests are relayed directly to Stripe’s DSAR form.
        </p>
      </header>
      <form action={queueExport} className="flex flex-col gap-2">
        <button
          type="submit"
          className="rounded-full bg-amber-400 px-4 py-2 text-sm font-semibold text-slate-950 transition hover:bg-amber-300"
        >
          Request export (JSON bundle)
        </button>
        <p className="text-xs text-slate-500">
          Generates a structured export using the <code>gdpr_data_exports</code> pipeline.
        </p>
      </form>
      <form action={queueErasure} className="flex flex-col gap-2">
        <button
          type="submit"
          className="rounded-full border border-amber-300 px-4 py-2 text-sm font-semibold text-amber-300 transition hover:bg-amber-300/10"
        >
          Request erasure
        </button>
        <p className="text-xs text-slate-500">
          Schedules erasure subject to booking retention policies and generates an audit event.
        </p>
      </form>
      <a
        href="https://support.stripe.com/questions/submit-a-data-subject-access-request"
        target="_blank"
        rel="noreferrer"
        className="text-xs text-amber-300 underline"
      >
        Request Stripe-held data
      </a>
    </div>
  );
}
