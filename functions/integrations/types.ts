export interface IntegrationProviderRow {
  code: string;
  name: string;
  category: string;
  description: string | null;
  supports_webhooks: boolean;
  supports_oauth: boolean;
  supports_polling: boolean;
  is_active: boolean;
  configuration_schema: Record<string, unknown>;
}

export interface IntegrationCapabilityRow {
  provider_code: string;
  capability_code: string;
  description: string | null;
  is_supported: boolean;
}

export interface TenantIntegrationRow {
  id: string;
  tenant_id: string;
  provider_code: string;
  credentials_ref: string | null;
  config: Record<string, unknown>;
  is_enabled: boolean;
  created_at: string;
  updated_at: string;
}

export interface WebhookDefinitionRow {
  id: string;
  tenant_id: string;
  provider_code: string;
  event_type: string;
  target_url: string;
  signing_secret_ref: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface DeviceIntegrationMapRow {
  id: string;
  tenant_id: string;
  device_id: string;
  provider_code: string;
  external_id: string;
  config: Record<string, unknown>;
  created_at: string;
}

export interface ConnectIntegrationRequest {
  provider_code: string;
  credentials_ref?: string;
  config?: Record<string, unknown>;
  is_enabled?: boolean;
}

export interface UpdateIntegrationRequest {
  provider_code: string;
  credentials_ref?: string | null;
  config?: Record<string, unknown>;
  is_enabled?: boolean;
}

export interface DisconnectIntegrationRequest {
  provider_code: string;
}

export interface CreateWebhookDefinitionRequest {
  provider_code: string;
  event_type: string;
  target_url: string;
  signing_secret_ref?: string;
  is_active?: boolean;
}

export interface UpdateWebhookDefinitionRequest {
  id: string;
  event_type?: string;
  target_url?: string;
  signing_secret_ref?: string | null;
  is_active?: boolean;
}

export interface CreateDeviceMapRequest {
  device_id: string;
  provider_code: string;
  external_id: string;
  config?: Record<string, unknown>;
}

export interface UpdateDeviceMapRequest {
  id: string;
  external_id?: string;
  config?: Record<string, unknown>;
}

export interface OAuthStartRequest {
  provider_code: string;
  redirect_uri?: string;
}

export interface OAuthStartResponse {
  authorize_url: string;
  state: string;
  provider_code: string;
}

export interface SyncIntegrationRequest {
  provider_code: string;
  scope?: Record<string, unknown>;
}

export interface SyncIntegrationResponse {
  queued: true;
  provider_code: string;
}
