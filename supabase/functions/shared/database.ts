/**
 * Database access layer.
 *
 * - Public schema: use Supabase JS client (RLS-aware with user JWT).
 * - Platform schema: direct Postgres (not exposed via PostgREST api.schemas).
 */

import postgres from "postgres";
import { config } from "./config.ts";
import { SqlBusinessError } from "./errors.ts";
import type { DatabaseClient } from "./supabase.ts";

let sqlInstance: ReturnType<typeof postgres> | null = null;

export function getSql(): ReturnType<typeof postgres> {
  if (!sqlInstance) {
    sqlInstance = postgres(config.databaseUrl(), {
      prepare: false,
      max: 3,
      idle_timeout: 20,
    });
  }
  return sqlInstance;
}

/** Invoke a void public-schema RPC via Supabase client. */
export async function callPublicVoid(
  client: DatabaseClient,
  fn: string,
  params: Record<string, unknown> = {},
): Promise<void> {
  const { error } = await client.rpc(fn, params);
  if (error) {
    throw new SqlBusinessError(error.message, {
      hint: error.hint,
      code: error.code,
      rpc: fn,
    });
  }
}

/** Call a public-schema RPC via Supabase client. */
export async function callPublicRpc<T>(
  client: DatabaseClient,
  fn: string,
  params: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = await client.rpc(fn, params);
  if (error) {
    throw new SqlBusinessError(error.message, {
      hint: error.hint,
      code: error.code,
      rpc: fn,
    });
  }
  return data as T;
}

/** Call a platform function returning a single scalar via direct Postgres. */
export async function callPlatformRpc<T>(
  fn: string,
  params: unknown[] = [],
): Promise<T> {
  const sql = getSql();
  const placeholders = params.map((_, i) => `$${i + 1}`).join(", ");
  const query = `select ${fn}(${placeholders}) as result`;

  try {
    const rows = await sql.unsafe(query, params as never[]);
    return rows[0]?.result as T;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new SqlBusinessError(message, { rpc: fn });
  }
}

/** Call a void platform function. */
export async function callPlatformVoid(
  fn: string,
  params: unknown[] = [],
): Promise<void> {
  const sql = getSql();
  const placeholders = params.map((_, i) => `$${i + 1}`).join(", ");
  await sql.unsafe(`select ${fn}(${placeholders})`, params as never[]);
}

export async function getScheduledJobId(jobName: string): Promise<string | null> {
  const sql = getSql();
  const rows = await sql<{ id: string }[]>`
    select id from platform.scheduled_jobs where job_name = ${jobName} limit 1
  `;
  return rows[0]?.id ?? null;
}

export async function logJobExecution(
  jobId: string | null,
  status: string,
  executionTimeMs: number,
  error?: string | null,
  correlationId?: string,
  attempt = 1,
): Promise<void> {
  await callPlatformVoid("platform.log_job_execution", [
    jobId,
    status,
    executionTimeMs,
    error ?? null,
    correlationId ?? crypto.randomUUID(),
    attempt,
  ]);
}

/** Platform logging — delegates to SQL SSOT. */
export async function logPlatformEvent(
  eventType: string,
  source: string,
  payload: Record<string, unknown> = {},
  severity = "info",
  correlationId?: string,
): Promise<void> {
  await callPlatformVoid("platform.log_event", [
    eventType,
    source,
    JSON.stringify(payload),
    severity,
    null,
    correlationId ?? crypto.randomUUID(),
  ]);
}

/** Persist inbound provider webhook via platform SSOT (000). Returns webhook row id. */
export async function ingestExternalWebhook(
  source: string,
  externalEventId: string,
  eventType: string,
  payload: Record<string, unknown>,
  tenantId?: string,
  externalAccountId?: string,
): Promise<string | null> {
  return await callPlatformRpc<string | null>(
    "platform.ingest_external_webhook",
    [
      source,
      externalEventId,
      eventType,
      JSON.stringify(payload),
      tenantId ?? null,
      externalAccountId ?? null,
    ],
  );
}

export async function processExternalWebhookBatch(limit = 50): Promise<Record<string, unknown>> {
  return await callPlatformRpc<Record<string, unknown>>(
    "platform.process_external_webhook_batch",
    [limit],
  );
}

export async function processIntegrationQueueBatch(
  limit: number,
): Promise<Record<string, unknown>> {
  return await callPlatformRpc<Record<string, unknown>>(
    "platform.process_integration_queue_batch",
    [limit],
  );
}

export async function processDeviceCommandBatch(
  limit: number,
  workerId: string,
): Promise<Record<string, unknown>> {
  return await callPlatformRpc<Record<string, unknown>>(
    "platform.process_device_command_batch",
    [limit, workerId],
  );
}

export async function processRetryTaskBatch(
  limit: number,
): Promise<Record<string, unknown>> {
  return await callPlatformRpc<Record<string, unknown>>(
    "platform.process_retry_task_batch",
    [limit],
  );
}

export async function processShipmentDispatchBatch(
  limit: number,
): Promise<Record<string, unknown>> {
  return await callPlatformRpc<Record<string, unknown>>(
    "platform.process_shipment_dispatch_batch",
    [limit],
  );
}

export async function processNotificationBatch(
  limit: number,
): Promise<Record<string, unknown>> {
  return await callPlatformRpc<Record<string, unknown>>(
    "platform.process_notification_batch",
    [limit],
  );
}

export async function processPaymentWebhook(webhookId: string): Promise<boolean> {
  return await callPlatformRpc<boolean>("platform.process_payment_webhook", [webhookId]);
}

export async function ingestShipmentTrackingEvent(
  carrierSource: string,
  externalEventId: string,
  fulfilmentOrderId: string,
  eventType: string,
  occurredAt: string,
  location?: string | null,
  payload: Record<string, unknown> = {},
): Promise<string> {
  return await callPlatformRpc<string>("platform.ingest_shipment_tracking_event", [
    carrierSource,
    externalEventId,
    fulfilmentOrderId,
    eventType,
    occurredAt,
    null,
    location ?? null,
    JSON.stringify(payload),
  ]);
}

export async function updateNodeHeartbeat(
  nodeType: string,
  nodeIdentifier: string,
  status: string,
  metadata: Record<string, unknown> = {},
): Promise<void> {
  await callPlatformVoid("platform.update_node_heartbeat", [
    nodeType,
    nodeIdentifier,
    status,
    JSON.stringify(metadata),
  ]);
}
