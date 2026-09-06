export interface IngestWebhookRequest {
  source: string;
  external_event_id: string;
  event_type: string;
  payload: Record<string, unknown>;
  tenant_id?: string;
  external_account_id?: string;
}

export interface IngestWebhookResult {
  ingested: true;
  source: string;
  external_event_id: string;
}

export interface StripeWebhookEvent {
  id: string;
  type: string;
  account?: string;
  data?: {
    object?: Record<string, unknown>;
  };
  [key: string]: unknown;
}
