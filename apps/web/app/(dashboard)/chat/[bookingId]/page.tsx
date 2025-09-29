import Link from "next/link";
import { notFound } from "next/navigation";
import { ChatThread } from "@/components/ChatThread";
import { JitsiMeetingFrame } from "@/components/JitsiMeetingFrame";
import { getBooking, getRecentMessages } from "@/lib/api";

interface PageProps {
  params: {
    bookingId: string;
  };
}

export default async function BookingChatPage({ params }: PageProps) {
  const booking = await getBooking(params.bookingId).catch(() => null);

  if (!booking) {
    notFound();
  }

  const initialMessages = await getRecentMessages(booking.id).catch(() => []);

  return (
    <div className="flex flex-col gap-6">
      <Link href="/dashboard/bookings" className="text-xs text-amber-300 underline">
        ← Back to bookings
      </Link>
      <section className="grid gap-6 lg:grid-cols-[1.2fr_1fr]">
        <ChatThread bookingId={booking.id} threadId={booking.id} initialMessages={initialMessages} />
        <aside className="card flex flex-col gap-4">
          <header>
            <h2 className="text-lg font-semibold text-white">Lesson room</h2>
            <p className="text-xs text-slate-400">Deterministic Jitsi room for this booking.</p>
          </header>
          <div className="flex flex-col gap-2 text-sm text-slate-300">
            <div>
              <span className="font-medium text-slate-100">Room:</span> {booking.jitsiRoom}
            </div>
            <div>
              <span className="font-medium text-slate-100">Status:</span>{" "}
              <span className={
                booking.status === "confirmed"
                  ? "badge badge-success"
                  : booking.status === "pending"
                    ? "badge badge-warning"
                    : "badge badge-danger"
              }>
                {booking.status}
              </span>
            </div>
          </div>
          {booking.status === "confirmed" ? (
            <JitsiMeetingFrame roomName={booking.jitsiRoom} userName="You" />
          ) : (
            <p className="text-xs text-slate-400">
              The Jitsi room unlocks after confirmation. We will email both parties if NAT issues
              appear so you can jump to an alternative meeting link.
            </p>
          )}
        </aside>
      </section>
    </div>
  );
}
