import { NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { apiBaseUrl } from "@/lib/config";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const threadId = searchParams.get("threadId");

  if (!threadId) {
    return NextResponse.json({ error: "threadId required" }, { status: 400 });
  }

  const session = await auth();
  if (!session?.user?.accessToken) {
    return NextResponse.json({ error: "Unauthenticated" }, { status: 401 });
  }

  const controller = new AbortController();
  request.signal.addEventListener("abort", () => {
    controller.abort();
  });

  const stream = new ReadableStream({
    async start(controllerStream) {
      const encoder = new TextEncoder();
      let since: string | undefined;
      let active = true;

      request.signal.addEventListener("abort", () => {
        active = false;
        controllerStream.close();
      });

      while (active) {
        try {
          const query = since ? `?since=${encodeURIComponent(since)}` : "";
          const response = await fetch(
            `${apiBaseUrl}/api/chat/threads/${threadId}/messages/recent${query}`,
            {
              headers: {
                Authorization: `Bearer ${session.user?.accessToken}`,
                Accept: "application/json"
              }
            }
          );

          if (!response.ok) {
            throw new Error(`Backend responded with ${response.status}`);
          }

          const messages: Array<{ id: string; sentAt: string; body: string; senderId: string }> =
            await response.json();

          if (messages.length > 0) {
            since = messages[messages.length - 1].sentAt;
            for (const message of messages) {
              const chunk = `event: message\ndata: ${JSON.stringify(message)}\n\n`;
              controllerStream.enqueue(encoder.encode(chunk));
            }
          }
        } catch (error) {
          const chunk = `event: error\ndata: ${JSON.stringify({ message: (error as Error).message })}\n\n`;
          controllerStream.enqueue(encoder.encode(chunk));
          active = false;
          controllerStream.close();
          break;
        }

        await new Promise((resolve) => setTimeout(resolve, 4000));
      }
    }
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      Connection: "keep-alive",
      "Cache-Control": "no-cache, no-transform"
    },
    signal: controller.signal
  });
}
