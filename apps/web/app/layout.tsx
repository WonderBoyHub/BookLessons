import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "BookLessons",
  description: "EU-first tutoring marketplace with secure booking, chat, and payments",
  metadataBase: new URL("https://booklessons.vercel.app"),
  openGraph: {
    title: "BookLessons",
    description: "Find EU-based tutors, pay securely, and join lessons in one place.",
    url: "https://booklessons.vercel.app",
    siteName: "BookLessons",
    type: "website"
  }
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="h-full bg-slate-950 text-slate-100">
      <body className="min-h-full font-sans antialiased">
        <div className="mx-auto flex min-h-screen w-full max-w-5xl flex-col gap-8 p-6">
          <header className="flex flex-col gap-2 border-b border-slate-800 pb-4">
            <p className="text-sm uppercase tracking-[0.3em] text-amber-400">BookLessons</p>
            <h1 className="text-2xl font-semibold text-white">Learn with confidence in the EU.</h1>
            <p className="max-w-2xl text-sm text-slate-300">
              Privacy-first tutoring sessions with verified tutors, Stripe payments, and
              GDPR-ready support for every subject.
            </p>
          </header>
          <main className="flex-1">{children}</main>
          <footer className="border-t border-slate-800 pt-4 text-xs text-slate-500">
            © {new Date().getFullYear()} BookLessons. All rights reserved.
          </footer>
        </div>
      </body>
    </html>
  );
}
