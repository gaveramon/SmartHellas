export interface AutomationRunRow {
  id: string;
  tenant_id: string;
  workflow_id: string;
  trigger_type: string;
  status: string;
  correlation_id: string;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
}

export interface AutomationRunDetail extends AutomationRunRow {
  trigger_payload: Record<string, unknown>;
  error_message: string | null;
}

export interface AutomationRunStepRow {
  id: string;
  run_id: string;
  workflow_step_id: string;
  step_order: number;
  action_type: string;
  status: string;
  result: Record<string, unknown>;
  started_at: string | null;
  completed_at: string | null;
}

export interface DispatchEventRequest {
  event_type: string;
  payload?: Record<string, unknown>;
}

export interface StartRunRequest {
  workflow_id: string;
  trigger_type: string;
  trigger_payload?: Record<string, unknown>;
}

export interface CancelRunRequest {
  id: string;
}

export interface AutomationSubscriptionRow {
  id: string;
  tenant_id: string;
  workflow_trigger_id: string;
  is_active: boolean;
  workflow_id?: string;
  trigger_type?: string;
  property_id?: string | null;
  created_at: string;
}

export interface UpsertSubscriptionRequest {
  workflow_trigger_id: string;
  is_active?: boolean;
}

export interface DeleteSubscriptionRequest {
  id: string;
}
