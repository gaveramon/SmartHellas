import { ValidationError } from "../shared/errors.ts";
import type {
  BatchOptions,
  NodeHeartbeatInput,
  ShipmentTrackingInput,
} from "./types.ts";

export interface PaymentWebhookOptions extends BatchOptions {
  webhook_id?: string;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const jobsIndex = segments.indexOf("jobs");
  if (jobsIndex >= 0 && segments.length > jobsIndex + 1) {
    return segments[jobsIndex + 1];
  }
  return segments[segments.length - 1] ?? "";
}

export function parseBatchOptions(body: unknown): BatchOptions {
  const defaultSize = 25;
  if (!body || typeof body !== "object") {
    return { batch_size: defaultSize };
  }
  const record = body as Record<string, unknown>;
  const size = record.batch_size;
  if (size === undefined) {
    return { batch_size: defaultSize };
  }
  if (typeof size !== "number" || size < 1 || size > 100) {
    throw new ValidationError("batch_size must be between 1 and 100");
  }
  return { batch_size: size };
}

export function parsePaymentWebhookOptions(body: unknown): PaymentWebhookOptions {
  const batch = parseBatchOptions(body);
  if (!body || typeof body !== "object") {
    return batch;
  }
  const record = body as Record<string, unknown>;
  const webhookId = record.webhook_id;
  if (webhookId === undefined) {
    return batch;
  }
  if (typeof webhookId !== "string" || !UUID_RE.test(webhookId)) {
    throw new ValidationError("webhook_id must be a valid UUID");
  }
  return { ...batch, webhook_id: webhookId };
}

export function parseShipmentTracking(body: unknown): ShipmentTrackingInput {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;

  const fulfilmentOrderId = r.fulfilment_order_id;
  if (typeof fulfilmentOrderId !== "string" || !UUID_RE.test(fulfilmentOrderId)) {
    throw new ValidationError("fulfilment_order_id must be a valid UUID");
  }

  const carrierSource = r.carrier_source;
  if (typeof carrierSource !== "string" || !carrierSource.trim()) {
    throw new ValidationError("carrier_source is required");
  }

  const externalEventId = r.external_event_id;
  if (typeof externalEventId !== "string" || !externalEventId.trim()) {
    throw new ValidationError("external_event_id is required");
  }

  const eventType = r.event_type;
  if (typeof eventType !== "string" || !eventType.trim()) {
    throw new ValidationError("event_type is required");
  }

  const occurredAt = r.occurred_at;
  if (typeof occurredAt !== "string" || !occurredAt.trim()) {
    throw new ValidationError("occurred_at is required (ISO timestamp)");
  }

  if (r.tenant_id !== undefined && r.tenant_id !== null) {
    throw new ValidationError(
      "tenant_id must not be supplied; derived from fulfilment_order",
      { field: "tenant_id" },
    );
  }

  const location = r.location;
  if (location !== undefined && location !== null && typeof location !== "string") {
    throw new ValidationError("location must be a string");
  }

  const payload = r.payload;
  if (payload !== undefined && payload !== null && typeof payload !== "object") {
    throw new ValidationError("payload must be an object");
  }

  return {
    carrier_source: carrierSource,
    external_event_id: externalEventId,
    fulfilment_order_id: fulfilmentOrderId,
    event_type: eventType,
    occurred_at: occurredAt,
    location: location as string | undefined,
    payload: (payload as Record<string, unknown>) ?? {},
  };
}

export function parseHeartbeat(body: unknown): NodeHeartbeatInput {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;

  const nodeType = r.node_type;
  if (typeof nodeType !== "string" || !nodeType.trim()) {
    throw new ValidationError("node_type is required");
  }

  const nodeIdentifier = r.node_identifier;
  if (typeof nodeIdentifier !== "string" || !nodeIdentifier.trim()) {
    throw new ValidationError("node_identifier is required");
  }

  const status = r.status;
  if (typeof status !== "string" || !status.trim()) {
    throw new ValidationError("status is required");
  }

  const metadata = r.metadata;
  if (metadata !== undefined && metadata !== null && typeof metadata !== "object") {
    throw new ValidationError("metadata must be an object");
  }

  return {
    node_type: nodeType,
    node_identifier: nodeIdentifier,
    status,
    metadata: (metadata as Record<string, unknown>) ?? {},
  };
}
