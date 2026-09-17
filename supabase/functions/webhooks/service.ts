import { ingestExternalWebhook } from "../shared/database.ts";
import type { IngestWebhookRequest, IngestWebhookResult } from "./types.ts";

/** Persist inbound provider webhook via platform SSOT (000). */
export async function ingestWebhook(
  input: IngestWebhookRequest,
): Promise<IngestWebhookResult> {
  await ingestExternalWebhook(
    input.source,
    input.external_event_id,
    input.event_type,
    input.payload,
    input.tenant_id,
    input.external_account_id,
  );

  return {
    ingested: true,
    source: input.source,
    external_event_id: input.external_event_id,
  };
}
