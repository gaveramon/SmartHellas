import { config } from "./config.ts";
import { ExternalApiError } from "./errors.ts";

export interface StripeClientConfig {
  secretKey: string;
}

export function getStripeConfig(): StripeClientConfig | null {
  const secretKey = config.stripeSecretKey();
  if (!secretKey) return null;
  return { secretKey };
}

/**
 * Stripe API orchestration — no billing logic.
 * Payment state transitions are handled by platform.apply_payment_status in SQL.
 */
export async function stripeRequest<T>(
  method: string,
  path: string,
  body?: Record<string, unknown>,
): Promise<T> {
  const stripeConfig = getStripeConfig();
  if (!stripeConfig) {
    throw new ExternalApiError("Stripe is not configured");
  }

  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${stripeConfig.secretKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: body ? encodeStripeBody(body) : undefined,
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new ExternalApiError(
      payload?.error?.message ?? "Stripe API request failed",
      { status: response.status, stripe: payload?.error },
    );
  }
  return payload as T;
}

function encodeStripeBody(data: Record<string, unknown>): string {
  const parts: string[] = [];
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    parts.push(
      `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`,
    );
  }
  return parts.join("&");
}

export async function verifyStripeWebhookSignature(
  payload: string,
  signatureHeader: string,
): Promise<boolean> {
  const secret = config.stripeWebhookSecret();
  if (!secret) return false;

  const elements = signatureHeader.split(",");
  const timestamp = elements.find((e) => e.startsWith("t="))?.slice(2);
  const signatures = elements
    .filter((e) => e.startsWith("v1="))
    .map((e) => e.slice(3));

  if (!timestamp || signatures.length === 0) return false;

  const signedPayload = `${timestamp}.${payload}`;
  const key = await awaitImportKey(secret);
  const expected = await awaitHmacSha256Hex(key, signedPayload);

  return signatures.some((sig) => sig === expected);
}

// Deno-compatible HMAC verification without node crypto
async function awaitImportKey(secret: string): Promise<CryptoKey> {
  const encoder = new TextEncoder();
  return await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function awaitHmacSha256Hex(
  key: CryptoKey,
  message: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(message),
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
