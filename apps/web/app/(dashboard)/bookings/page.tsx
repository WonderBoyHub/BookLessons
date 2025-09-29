import Link from "next/link";
import { Suspense } from "react";
import { getBookings } from "@/lib/api";

async function BookingsTable() {
  const bookings = await getBookings();

  return (
    <div className="card">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-white">Bookings</h2>
          <p className="text-xs text-slate-400">Live data from the ASP.NET Core API.</p>
        </div>
        <Link
          href="/dashboard/gdpr"
          className="rounded-full border border-amber-400 px-4 py-1.5 text-xs font-semibold uppercase tracking-wide text-amber-300"
        >
          GDPR Center
        </Link>
      </div>
      <table className="table mt-6">
        <thead>
          <tr>
            <th>ID</th>
            <th>Subject</th>
            <th>When</th>
            <th>Price</th>
            <th>Status</th>
            <th>Room</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {bookings.map((booking) => {
            const start = new Date(booking.scheduledStart);
            const end = new Date(booking.scheduledEnd);
            const statusClass =
              booking.status === "confirmed"
                ? "badge badge-success"
                : booking.status === "pending"
                  ? "badge badge-warning"
                  : booking.status === "cancelled"
                    ? "badge badge-danger"
                    : "badge";
            return (
              <tr key={booking.id}>
                <td className="font-mono text-xs text-slate-400">{booking.id}</td>
                <td>{booking.subject}</td>
                <td className="text-xs text-slate-300">
                  {start.toLocaleString()} → {end.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                </td>
                <td>
                  {(booking.priceCents / 100).toLocaleString(undefined, {
                    style: "currency",
                    currency: booking.currency
                  })}
                </td>
                <td>
                  <span className={statusClass}>{booking.status}</span>
                </td>
                <td className="text-xs text-slate-300">{booking.jitsiRoom}</td>
                <td>
                  <Link className="text-xs text-amber-300 underline" href={`/dashboard/chat/${booking.id}`}>
                    Open chat
                  </Link>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export default function BookingsPage() {
  return (
    <Suspense fallback={<div className="card">Loading bookings…</div>}>
      {/* @ts-expect-error Async Server Component */}
      <BookingsTable />
    </Suspense>
  );
}
