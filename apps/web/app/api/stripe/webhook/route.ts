import { headers } from "next/headers";
import { NextResponse } from "next/server";
import Stripe from "stripe";
import { apiBaseUrl } from "@/lib/config";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? "", {
  apiVersion: "2023-10-16"
});

export async function POST(request: Request) {
  const payload = await request.text();
  const sig = headers().get("stripe-signature");
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!sig || !webhookSecret) {
    return NextResponse.json({ error: "Missing Stripe signature" }, { status: 400 });
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(payload, sig, webhookSecret);
  } catch (error) {
    return NextResponse.json({ error: `Webhook signature verification failed: ${(error as Error).message}` }, { status: 400 });
  }

  await fetch(`${apiBaseUrl}/api/payments/stripe/webhook`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json"
    },
    body: JSON.stringify(event)
  });

  return NextResponse.json({ received: true });
}
