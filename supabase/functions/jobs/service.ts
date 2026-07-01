import { ValidationError } from "../shared/errors.ts";
import { config } from "../shared/config.ts";
import {
  getScheduledJobId,
  ingestShipmentTrackingEvent,
  logJobExecution,
  logPlatformEvent,
  processDeviceCommandBatch,
  processExternalWebhookBatch,
  processIntegrationQueueBatch,
  processNotificationBatch,
  processPaymentWebhook,
  processRetryTaskBatch,
  processShipmentDispatchBatch,
  updateNodeHeartbeat,
} from "../shared/database.ts";
import {
  runPlatformCronTick,
  runPlatformDailyMaintenance,
} from "../shared/queue.ts";
import type {
  BatchOptions,
  NodeHeartbeatInput,
  ShipmentTrackingInput,
  WorkerBatchResult,
} from "./types.ts";
import type { PaymentWebhookOptions } from "./validation.ts";

const WORKER_ID = config.nodeIdentifier();

function batchResult(
  result: Record<string, unknown>,
  correlationId: string,
  details?: Record<string, unknown>,
): WorkerBatchResult {
  const processed = Number(result.processed ?? 0);
  const succeeded = Number(result.succeeded ?? 0);
  const failed = Number(result.failed ?? 0);

  return {
    processed,
    succeeded,
    failed,
    correlation_id: correlationId,
    details: details ? { ...result, ...details } : result,
  };
}

export async function runDeviceCommandWorker(
  options: BatchOptions,
  correlationId: string,
): Promise<WorkerBatchResult> {
  const result = await processDeviceCommandBatch(options.batch_size, WORKER_ID);
  await logPlatformEvent(
    "device_command.batch",
    "jobs/device-commands",
    result,
    Number(result.failed ?? 0) > 0 ? "warn" : "info",
    correlationId,
  );
  return batchResult(result, correlationId);
}

export async function runIntegrationQueueWorker(
  options: BatchOptions,
  correlationId: string,
): Promise<WorkerBatchResult> {
  const result = await processIntegrationQueueBatch(options.batch_size);
  return batchResult(result, correlationId);
}

export async function runRetryTaskWorker(
  options: BatchOptions,
  correlationId: string,
): Promise<WorkerBatchResult> {
  const result = await processRetryTaskBatch(options.batch_size);
  return batchResult(result, correlationId);
}

export async function runShipmentDispatchWorker(
  options: BatchOptions,
  correlationId: string,
): Promise<WorkerBatchResult> {
  const result = await processShipmentDispatchBatch(options.batch_size);
  return batchResult(result, correlationId);
}

export async function ingestShipmentTracking(
  input: ShipmentTrackingInput,
  correlationId: string,
): Promise<{ event_id: string; duplicate?: boolean }> {
  const eventId = await ingestShipmentTrackingEvent(
    input.carrier_source,
    input.external_event_id,
    input.fulfilment_order_id,
    input.event_type,
    input.occurred_at,
    input.location,
    input.payload ?? {},
  );

  await logPlatformEvent(
    "shipment.tracking.ingested",
    "jobs/shipment-tracking",
    {
      event_id: eventId ?? input.external_event_id,
      fulfilment_order_id: input.fulfilment_order_id,
      duplicate: !eventId,
    },
    "info",
    correlationId,
  );

  return { event_id: eventId ?? input.external_event_id, duplicate: !eventId };
}

export async function recordHeartbeat(
  input: NodeHeartbeatInput,
  correlationId: string,
): Promise<void> {
  await updateNodeHeartbeat(
    input.node_type,
    input.node_identifier,
    input.status,
    input.metadata ?? {},
  );

  await logPlatformEvent(
    "node.heartbeat",
    "jobs/heartbeat",
    {
      node_type: input.node_type,
      node_identifier: input.node_identifier,
      status: input.status,
    },
    "info",
    correlationId,
  );
}

export async function runNotificationsDeliveryWorker(
  options: BatchOptions,
  correlationId: string,
): Promise<WorkerBatchResult> {
  const result = await processNotificationBatch(options.batch_size);
  await logPlatformEvent(
    "notifications.delivery.batch",
    "jobs/notifications-delivery",
    result,
    Number(result.failed ?? 0) > 0 ? "warn" : "info",
    correlationId,
  );
  return batchResult(result, correlationId);
}

export async function runWebhooksWorker(
  options: BatchOptions,
  correlationId: string,
): Promise<WorkerBatchResult> {
  const result = await processExternalWebhookBatch(options.batch_size);
  await logPlatformEvent(
    "webhooks.process.batch",
    "jobs/webhooks-worker",
    result,
    "info",
    correlationId,
  );
  return batchResult(result, correlationId);
}

export async function runPaymentWebhookWorker(
  options: PaymentWebhookOptions,
  correlationId: string,
): Promise<WorkerBatchResult> {
  if (!options.webhook_id) {
    throw new ValidationError(
      "webhook_id is required; use jobs/webhooks-worker for batch processing",
    );
  }

  try {
    const handled = await processPaymentWebhook(options.webhook_id);
    return {
      processed: 1,
      succeeded: handled ? 1 : 0,
      failed: handled ? 0 : 1,
      correlation_id: correlationId,
      details: { webhook_id: options.webhook_id, handled },
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      processed: 1,
      succeeded: 0,
      failed: 1,
      correlation_id: correlationId,
      details: { webhook_id: options.webhook_id, error: message },
    };
  }
}

export async function runCronTickJob(correlationId: string): Promise<WorkerBatchResult> {
  const started = Date.now();
  const jobId = await getScheduledJobId("platform-cron-tick");

  try {
    await runPlatformCronTick();
    const elapsed = Date.now() - started;
    await logJobExecution(jobId, "success", elapsed, null, correlationId);
    return {
      processed: 1,
      succeeded: 1,
      failed: 0,
      correlation_id: correlationId,
      details: { job: "platform-cron-tick", elapsed_ms: elapsed },
    };
  } catch (error) {
    const elapsed = Date.now() - started;
    const message = error instanceof Error ? error.message : String(error);
    await logJobExecution(jobId, "failed", elapsed, message, correlationId);
    throw error;
  }
}

export async function runDailyMaintenanceJob(
  correlationId: string,
): Promise<WorkerBatchResult> {
  const started = Date.now();
  const jobId = await getScheduledJobId("platform-daily-maintenance");

  try {
    await runPlatformDailyMaintenance();
    const elapsed = Date.now() - started;
    await logJobExecution(jobId, "success", elapsed, null, correlationId);
    return {
      processed: 1,
      succeeded: 1,
      failed: 0,
      correlation_id: correlationId,
      details: { job: "platform-daily-maintenance", elapsed_ms: elapsed },
    };
  } catch (error) {
    const elapsed = Date.now() - started;
    const message = error instanceof Error ? error.message : String(error);
    await logJobExecution(jobId, "failed", elapsed, message, correlationId);
    throw error;
  }
}
