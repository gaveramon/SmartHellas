export interface NotificationTemplateRow {
  id: string;
  tenant_id: string | null;
  code: string;
  channel: string;
  subject_template: string | null;
  body_template: string;
  metadata: Record<string, unknown>;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface NotificationPreferenceRow {
  id: string;
  tenant_id: string;
  user_id: string | null;
  channel: string;
  is_enabled: boolean;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface NotificationQueueRow {
  id: string;
  tenant_id: string;
  channel: string;
  recipient: string;
  template_code: string | null;
  status: string;
  scheduled_at: string;
  attempt_count: number;
  max_attempts: number;
  correlation_id: string;
  source: string;
  created_at: string;
  updated_at: string;
}

export interface NotificationHistoryRow {
  id: string;
  tenant_id: string;
  queue_id: string | null;
  channel: string;
  recipient: string;
  status: string;
  subject: string | null;
  body?: string;
  payload: Record<string, unknown>;
  error: Record<string, unknown> | null;
  sent_at: string;
  created_at: string;
}

export interface EnqueueNotificationRequest {
  channel: string;
  recipient: string;
  template_code?: string;
  subject?: string;
  body?: string;
  payload?: Record<string, unknown>;
  user_id?: string;
  scheduled_at?: string;
}

export interface UpsertPreferenceRequest {
  channel: string;
  is_enabled?: boolean;
  user_id?: string;
  metadata?: Record<string, unknown>;
}

export interface CancelNotificationRequest {
  id: string;
}
