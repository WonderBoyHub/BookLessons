"use client";

import { useEffect, useRef, useState } from "react";
import type { ChatMessage } from "@/lib/api";

interface ChatThreadProps {
  threadId: string;
  bookingId: string;
  initialMessages: ChatMessage[];
}

export function ChatThread({ threadId, bookingId, initialMessages }: ChatThreadProps) {
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);
  const [error, setError] = useState<string | null>(null);
  const bottomRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const source = new EventSource(`/api/chat/stream?threadId=${threadId}`);

    source.addEventListener("message", (event) => {
      const data = JSON.parse(event.data) as ChatMessage;
      setMessages((current) => {
        if (current.some((msg) => msg.id === data.id)) {
          return current;
        }
        return [...current, data];
      });
    });

    source.addEventListener("error", (event) => {
      setError("Connection interrupted. Retrying…");
      console.error("SSE error", event);
    });

    return () => {
      source.close();
    };
  }, [threadId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  return (
    <div className="card flex flex-col gap-4">
      <header>
        <h2 className="text-lg font-semibold text-white">Chat for booking {bookingId}</h2>
        <p className="text-xs text-slate-400">Messages refresh automatically through SSE.</p>
      </header>
      <div className="flex max-h-80 flex-col gap-2 overflow-y-auto rounded-lg border border-slate-800 p-3">
        {messages.length === 0 && (
          <p className="text-sm text-slate-400">No messages yet. Say hi to start the conversation.</p>
        )}
        {messages.map((message) => (
          <article key={message.id} className="rounded-lg border border-slate-800/60 bg-slate-900/60 p-3">
            <div className="flex items-center justify-between text-xs text-slate-500">
              <span className="font-medium text-amber-200">{message.senderId}</span>
              <time dateTime={message.sentAt}>
                {new Date(message.sentAt).toLocaleString(undefined, {
                  hour: "2-digit",
                  minute: "2-digit",
                  day: "2-digit",
                  month: "short"
                })}
              </time>
            </div>
            <p className="mt-2 text-sm text-slate-200">{message.body}</p>
          </article>
        ))}
        <div ref={bottomRef} />
      </div>
      {error ? <p className="text-xs text-amber-300">{error}</p> : null}
    </div>
  );
}
