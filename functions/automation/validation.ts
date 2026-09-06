import { ValidationError } from "../shared/errors.ts";
import type {
  CancelRunRequest,
  DeleteSubscriptionRequest,
  DispatchEventRequest,
  StartRunRequest,
  UpsertSubscriptionRequest,
} from "./types.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseUuidQuery(req: Request, key = "id"): string {
  const url = new URL(req.url);
  const value = url.searchParams.get(key);
  if (!value || !isUuid(value)) {
    throw new ValidationError(`Valid UUID query parameter '${key}' required`);
  }
  return value;
}

export function optionalUuidQuery(req: Request, key: string): string | undefined {
  const url = new URL(req.url);
  const value = url.searchParams.get(key);
  if (!value) return undefined;
  if (!isUuid(value)) {
    throw new ValidationError(`Invalid UUID for '${key}'`);
  }
  return value;
}

export function parseDispatchEventBody(body: unknown): DispatchEventRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("JSON body required");
  }
  const record = body as Record<string, unknown>;
  if (typeof record.event_type !== "string" || !record.event_type.trim()) {
    throw new ValidationError("event_type is required");
  }
  return {
    event_type: record.event_type.trim(),
    payload: record.payload as Record<string, unknown> | undefined,
  };
}

export function parseStartRunBody(body: unknown): StartRunRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("JSON body required");
  }
  const record = body as Record<string, unknown>;
  if (typeof record.workflow_id !== "string" || !isUuid(record.workflow_id)) {
    throw new ValidationError("Valid workflow_id required");
  }
  if (typeof record.trigger_type !== "string" || !record.trigger_type.trim()) {
    throw new ValidationError("trigger_type is required");
  }
  return {
    workflow_id: record.workflow_id,
    trigger_type: record.trigger_type.trim(),
    trigger_payload: record.trigger_payload as Record<string, unknown> | undefined,
  };
}

export function parseCancelRunBody(body: unknown): CancelRunRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("JSON body required");
  }
  const record = body as Record<string, unknown>;
  if (typeof record.id !== "string" || !isUuid(record.id)) {
    throw new ValidationError("Valid id required");
  }
  return { id: record.id };
}

export function parseUpsertSubscriptionBody(body: unknown): UpsertSubscriptionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("JSON body required");
  }
  const record = body as Record<string, unknown>;
  if (
    typeof record.workflow_trigger_id !== "string" ||
    !isUuid(record.workflow_trigger_id)
  ) {
    throw new ValidationError("Valid workflow_trigger_id required");
  }
  const result: UpsertSubscriptionRequest = {
    workflow_trigger_id: record.workflow_trigger_id,
  };
  if (record.is_active !== undefined) {
    if (typeof record.is_active !== "boolean") {
      throw new ValidationError("is_active must be a boolean");
    }
    result.is_active = record.is_active;
  }
  return result;
}

export function parseDeleteSubscriptionBody(body: unknown): DeleteSubscriptionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("JSON body required");
  }
  const record = body as Record<string, unknown>;
  if (typeof record.id !== "string" || !isUuid(record.id)) {
    throw new ValidationError("Valid id required");
  }
  return { id: record.id };
}
