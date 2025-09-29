"use client";

import { useEffect, useRef } from "react";

declare global {
  interface Window {
    JitsiMeetExternalAPI?: new (domain: string, options: Record<string, unknown>) => {
      dispose: () => void;
    };
  }
}

interface Props {
  roomName: string;
  userName: string;
  domain?: string;
}

export function JitsiMeetingFrame({ roomName, userName, domain = process.env.NEXT_PUBLIC_JITSI_DOMAIN ?? "meet.jit.si" }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const apiRef = useRef<{ dispose: () => void } | null>(null);

  useEffect(() => {
    const scriptId = "jitsi-external-api";
    if (!document.getElementById(scriptId)) {
      const script = document.createElement("script");
      script.id = scriptId;
      script.src = `https://${domain}/external_api.js`;
      script.async = true;
      document.body.appendChild(script);
    }

    function initialize() {
      if (!window.JitsiMeetExternalAPI || !containerRef.current) {
        return;
      }
      apiRef.current = new window.JitsiMeetExternalAPI(domain, {
        roomName,
        parentNode: containerRef.current,
        configOverwrite: {
          prejoinPageEnabled: false
        },
        interfaceConfigOverwrite: {
          DISABLE_JOIN_LEAVE_NOTIFICATIONS: true
        },
        userInfo: {
          displayName: userName
        }
      });
    }

    const timeout = setTimeout(initialize, 800);

    return () => {
      clearTimeout(timeout);
      apiRef.current?.dispose();
    };
  }, [domain, roomName, userName]);

  return <div ref={containerRef} className="aspect-video w-full overflow-hidden rounded-xl border border-slate-800" />;
}
