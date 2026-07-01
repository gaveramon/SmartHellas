export interface PaymentIntentRow {
  id: string;
  tenant_id: string;
  provider: string;
  external_intent_id: string | null;
  amount: number;
  currency: string;
  status: string;
  target_type: string;
  target_id: string;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface PaymentEventRow {
  id: string;
  payment_intent_id: string;
  event_type: string;
  old_status: string | null;
  new_status: string;
  source: string;
  external_event_id: string | null;
  payload: Record<string, unknown>;
  created_at: string;
}

export interface CreateCheckoutSessionRequest {
  provider: string;
  amount: number;
  currency?: string;
  target_type: string;
  target_id: string;
  metadata?: Record<string, unknown>;
}

export interface CancelPaymentRequest {
  id: string;
  metadata?: Record<string, unknown>;
}
