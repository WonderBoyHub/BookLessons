import "server-only";

import { apiBaseUrl } from "./config";
import { auth } from "./auth";

export interface Booking {
  id: string;
  tutorId: string;
  studentId: string;
  subject: string;
  scheduledStart: string;
  scheduledEnd: string;
  status: "pending" | "confirmed" | "cancelled" | "completed";
  priceCents: number;
  currency: string;
  jitsiRoom: string;
}

export interface ChatMessage {
  id: string;
  threadId: string;
  senderId: string;
  sentAt: string;
  body: string;
}

async function authorizedFetch(input: string, init?: RequestInit) {
  const session = await auth();
  const headers = new Headers(init?.headers);
  headers.set("Accept", "application/json");
  headers.set("Content-Type", "application/json");
  if (session?.user?.accessToken) {
    headers.set("Authorization", `Bearer ${session.user.accessToken}`);
  }

  return fetch(`${apiBaseUrl}${input}`, {
    ...init,
    headers
  });
}

export async function getBookings(): Promise<Booking[]> {
  const response = await authorizedFetch("/api/bookings");
  if (!response.ok) {
    throw new Error(`Unable to load bookings (${response.status})`);
  }
  return response.json();
}

export async function getBooking(bookingId: string): Promise<Booking> {
  const response = await authorizedFetch(`/api/bookings/${bookingId}`);
  if (!response.ok) {
    throw new Error("Booking not found");
  }
  return response.json();
}

export async function getRecentMessages(threadId: string, sinceIso?: string): Promise<ChatMessage[]> {
  const query = sinceIso ? `?since=${encodeURIComponent(sinceIso)}` : "";
  const response = await authorizedFetch(`/api/chat/threads/${threadId}/messages/recent${query}`);
  if (!response.ok) {
    throw new Error("Could not load chat messages");
  }
  return response.json();
}

export async function requestDataExport() {
  const response = await authorizedFetch("/api/gdpr/export", {
    method: "POST"
  });
  if (!response.ok) {
    throw new Error("Failed to queue export request");
  }
}

export async function requestDataErasure() {
  const response = await authorizedFetch("/api/gdpr/erase", {
    method: "POST"
  });
  if (!response.ok) {
    throw new Error("Failed to queue erasure request");
  }
}
