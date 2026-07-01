import { UnauthorizedError } from "./errors.ts";

export interface WebhookVerificationOptions {
  secret: string;
  signatureHeader: string;
  payload: string;
  algorithm?: "sha256" | "sha1";
}

/** HMAC webhook signature verification — generic helper for provider webhooks. */
export async function verifyWebhookSignature(
  options: WebhookVerificationOptions,
): Promise<boolean> {
  const algorithm = options.algorithm ?? "sha256";
  const encoder = new TextEncoder();

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(options.secret),
    { name: "HMAC", hash: algorithm === "sha1" ? "SHA-1" : "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(options.payload),
  );

  const expected = Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  const provided = options.signatureHeader
    .replace(/^sha256=/, "")
    .replace(/^sha1=/, "")
    .trim();

  return timingSafeEqual(expected, provided);
}

export async function requireWebhookSignature(
  options: WebhookVerificationOptions,
): Promise<void> {
  const valid = await verifyWebhookSignature(options);
  if (!valid) {
    throw new UnauthorizedError("Invalid webhook signature");
  }
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

/** Parse raw webhook body once — avoids double-read issues. */
export async function readWebhookBody(req: Request): Promise<string> {
  return await req.text();
}
