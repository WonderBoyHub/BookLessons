import { NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { apiBaseUrl } from "@/lib/config";

export async function POST() {
  const session = await auth();
  if (!session?.user?.accessToken) {
    return NextResponse.json({ error: "Unauthenticated" }, { status: 401 });
  }

  const response = await fetch(`${apiBaseUrl}/api/gdpr/export`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${session.user.accessToken}`,
      Accept: "application/json"
    }
  });

  if (!response.ok) {
    return NextResponse.json({ error: "Backend failed" }, { status: response.status });
  }

  return NextResponse.json({ queued: true });
}
