export const metadata = {
  title: "Privacy Policy — BookLessons"
};

export default function PrivacyPage() {
  return (
    <article className="card prose prose-invert max-w-none">
      <h2>Privacy Policy</h2>
      <p>
        BookLessons UG (haftungsbeschränkt) acts as the data controller for tutoring bookings and
        learning content stored within our Neon Postgres database hosted in the European Union.
      </p>
      <h3>Legal bases</h3>
      <ul>
        <li>Contractual necessity for booking management, payments, and chat.</li>
        <li>Legitimate interest for fraud prevention and service security.</li>
        <li>Consent for marketing communications and optional cookies.</li>
      </ul>
      <h3>Processors</h3>
      <ul>
        <li>Vercel (EU regions, hosting this Next.js frontend).</li>
        <li>Azure Web Apps (hosts the Blazor operations console).</li>
        <li>Stripe (payments and financial compliance).</li>
        <li>Jitsi (meet.jit.si, live lesson video; subject to 8x8 ToS).</li>
      </ul>
      <h3>International transfers</h3>
      <p>
        Where processors rely on sub-processors located outside the EEA, we execute the Standard
        Contractual Clauses (SCCs) provided by each vendor and document the transfer impact
        assessment.
      </p>
      <h3>Data subject rights</h3>
      <p>
        You can request a copy of your data or ask for erasure directly from the dashboard. Stripe
        retains cardholder data as an independent controller; submit their DSAR form for Stripe-held
        records.
      </p>
      <h3>Contact</h3>
      <p>
        Email privacy@booklessons.eu for any privacy or security questions. We respond within 72
        hours and document all requests in our audit log.
      </p>
    </article>
  );
}
