export type JobRoute =
  | "cron-tick"
  | "daily-maintenance"
  | "device-commands"
  | "integration-queue"
  | "retry-tasks"
  | "shipment-dispatch"
  | "shipment-tracking"
  | "heartbeat"
  | "webhooks-worker"
  | "notifications-delivery"
  | "payment-webhook";

export interface WorkerBatchResult {
  processed: number;
  succeeded: number;
  failed: number;
  correlation_id: string;
  details?: Record<string, unknown>;
}

export interface ShipmentTrackingInput {
  carrier_source: string;
  external_event_id: string;
  fulfilment_order_id: string;
  event_type: string;
  occurred_at: string;
  location?: string;
  payload?: Record<string, unknown>;
}

export interface NodeHeartbeatInput {
  node_type: string;
  node_identifier: string;
  status: string;
  metadata?: Record<string, unknown>;
}

export interface BatchOptions {
  batch_size: number;
}
