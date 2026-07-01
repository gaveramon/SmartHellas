import { createRouteResolver } from "../shared/core/index.ts";
import type { JobRouteHandlerMap } from "../shared/core/index.ts";
import { cronTickHandler } from "./handlers/cron_tick.ts";
import { dailyMaintenanceHandler } from "./handlers/daily_maintenance.ts";
import { deviceCommandsHandler } from "./handlers/device_commands.ts";
import { integrationQueueHandler } from "./handlers/integration_queue.ts";
import { retryTasksHandler } from "./handlers/retry_tasks.ts";
import { shipmentDispatchHandler } from "./handlers/shipment_dispatch.ts";
import { shipmentTrackingHandler } from "./handlers/shipment_tracking.ts";
import { heartbeatHandler } from "./handlers/heartbeat.ts";
import { notificationsDeliveryHandler } from "./handlers/notifications_delivery.ts";
import { webhooksWorkerHandler } from "./handlers/webhooks_worker.ts";
import { paymentWebhookHandler } from "./handlers/payment_webhook.ts";

export const resolveRoute = createRouteResolver("jobs");

export const routeHandlers: JobRouteHandlerMap = {
  "cron-tick": cronTickHandler,
  "daily-maintenance": dailyMaintenanceHandler,
  "device-commands": deviceCommandsHandler,
  "integration-queue": integrationQueueHandler,
  "retry-tasks": retryTasksHandler,
  "shipment-dispatch": shipmentDispatchHandler,
  "shipment-tracking": shipmentTrackingHandler,
  "heartbeat": heartbeatHandler,
  "webhooks-worker": webhooksWorkerHandler,
  "notifications-delivery": notificationsDeliveryHandler,
  "payment-webhook": paymentWebhookHandler,
};
