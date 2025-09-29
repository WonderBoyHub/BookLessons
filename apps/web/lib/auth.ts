import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { z } from "zod";
import { trustedBackendUrl } from "./config";

const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1)
});

export const {
  handlers: { GET, POST },
  auth,
  signIn,
  signOut
} = NextAuth({
  session: {
    strategy: "jwt"
  },
  trustHost: true,
  providers: [
    Credentials({
      async authorize(credentials) {
        const parsed = credentialsSchema.safeParse(credentials);
        if (!parsed.success) {
          return null;
        }

        const response = await fetch(`${trustedBackendUrl}/api/auth/login`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json"
          },
          body: JSON.stringify(parsed.data)
        });

        if (!response.ok) {
          return null;
        }

        const payload = await response.json();
        return {
          id: payload.userId,
          email: parsed.data.email,
          name: payload.displayName,
          role: payload.role,
          accessToken: payload.accessToken
        };
      }
    })
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.accessToken = (user as any).accessToken;
        token.role = (user as any).role;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.accessToken = token.accessToken as string | undefined;
        session.user.role = token.role as string | undefined;
      }
      return session;
    }
  }
});
