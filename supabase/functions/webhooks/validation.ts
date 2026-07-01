import { ValidationError } from "../shared/errors.ts";
import type { IngestWebhookRequest } from "./types.ts";

const SOURCE_RE = /^[a-z0-9_-]{1,64}$/i;

export function parseIngestWebhookBody(body: unknown): IngestWebhookRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;

  if (typeof r.source !== "string" || !SOURCE_RE.test(r.source.trim())) {
    throw new ValidationError("source is required (1-64 alphanumeric/underscore/dash)");
  }
  if (typeof r.external_event_id !== "string" || !r.external_event_id.trim()) {
    throw new ValidationError("external_event_id is required");
  }
  if (typeof r.event_type !== "string" || !r.event_type.trim()) {
    throw new ValidationError("event_type is required");
  }
  if (typeof r.payload !== "object" || r.payload === null || Array.isArray(r.payload)) {
    throw new ValidationError("payload must be a JSON object");
  }

  const result: IngestWebhookRequest = {
    source: r.source.trim().toLowerCase(),
    external_event_id: r.external_event_id.trim(),
    event_type: r.event_type.trim(),
    payload: r.payload as Record<string, unknown>,
  };

  if (r.tenant_id !== undefined && r.tenant_id !== null) {
    if (typeof r.tenant_id !== "string") {
      throw new ValidationError("tenant_id must be a UUID string");
    }
    result.tenant_id = r.tenant_id;
  }
  if (r.external_account_id !== undefined && r.external_account_id !== null) {
    if (typeof r.external_account_id !== "string" || !r.external_account_id.trim()) {
      throw new ValidationError("external_account_id must be a non-empty string");
    }
    result.external_account_id = r.external_account_id.trim();
  }

  return result;
}

export function parseProviderSource(req: Request, fallbackSource: string): string {
  const querySource = new URL(req.url).searchParams.get("source");
  const source = (querySource ?? fallbackSource).trim().toLowerCase();
  if (!SOURCE_RE.test(source)) {
    throw new ValidationError("Invalid provider source");
  }
  return source;
}

export function parseStripeEvent(body: unknown): {
  id: string;
  type: string;
  account?: string;
  payload: Record<string, unknown>;
} {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Stripe webhook body must be a JSON object");
  }
  const event = body as Record<string, unknown>;
  if (typeof event.id !== "string" || !event.id.trim()) {
    throw new ValidationError("Stripe event id missing");
  }
  if (typeof event.type !== "string" || !event.type.trim()) {
    throw new ValidationError("Stripe event type missing");
  }
  return {
    id: event.id,
    type: event.type,
    account: typeof event.account === "string" ? event.account : undefined,
    payload: event as Record<string, unknown>,
  };
}
