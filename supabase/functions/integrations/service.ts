import { type AuthContext } from "../shared/auth.ts";
import { callModuleApiAuth, callModuleApiService } from "../shared/edge-rpc.ts";
import type {
  ConnectIntegrationRequest,
  CreateDeviceMapRequest,
  CreateWebhookDefinitionRequest,
  DeviceIntegrationMapRow,
  DisconnectIntegrationRequest,
  IntegrationCapabilityRow,
  IntegrationProviderRow,
  OAuthStartRequest,
  OAuthStartResponse,
  SyncIntegrationRequest,
  SyncIntegrationResponse,
  TenantIntegrationRow,
  UpdateDeviceMapRequest,
  UpdateIntegrationRequest,
  UpdateWebhookDefinitionRequest,
  WebhookDefinitionRow,
} from "./types.ts";

export async function listProviders(auth: AuthContext): Promise<IntegrationProviderRow[]> {
  return await callModuleApiAuth<IntegrationProviderRow[]>(
    auth,
    "integrations",
    "list_providers",
  );
}

export async function getProvider(
  auth: AuthContext,
  code: string,
): Promise<IntegrationProviderRow> {
  return await callModuleApiAuth<IntegrationProviderRow>(
    auth,
    "integrations",
    "get_provider",
    { code },
  );
}

export async function listCapabilities(
  auth: AuthContext,
  providerCode?: string,
): Promise<IntegrationCapabilityRow[]> {
  return await callModuleApiAuth<IntegrationCapabilityRow[]>(
    auth,
    "integrations",
    "list_capabilities",
    providerCode ? { provider_code: providerCode } : {},
  );
}

export async function listTenantIntegrations(
  auth: AuthContext,
): Promise<TenantIntegrationRow[]> {
  return await callModuleApiAuth<TenantIntegrationRow[]>(
    auth,
    "integrations",
    "list_tenant_integrations",
  );
}

export async function getTenantIntegration(
  auth: AuthContext,
  providerCode: string,
): Promise<TenantIntegrationRow | null> {
  return await callModuleApiAuth<TenantIntegrationRow | null>(
    auth,
    "integrations",
    "get_tenant_integration",
    { provider_code: providerCode },
  );
}

export async function connectIntegration(
  auth: AuthContext,
  input: ConnectIntegrationRequest,
): Promise<TenantIntegrationRow> {
  const payload: Record<string, unknown> = {
    provider_code: input.provider_code,
    config: input.config ?? {},
    is_enabled: input.is_enabled ?? true,
  };
  if (input.credentials_ref !== undefined) {
    payload.credentials_ref = input.credentials_ref;
  }

  return await callModuleApiAuth<TenantIntegrationRow>(
    auth,
    "integrations",
    "connect_integration",
    payload,
  );
}

export async function updateIntegration(
  auth: AuthContext,
  input: UpdateIntegrationRequest,
): Promise<TenantIntegrationRow> {
  const payload: Record<string, unknown> = {
    provider_code: input.provider_code,
  };
  if (input.credentials_ref !== undefined) payload.credentials_ref = input.credentials_ref;
  if (input.config !== undefined) payload.config = input.config;
  if (input.is_enabled !== undefined) payload.is_enabled = input.is_enabled;

  return await callModuleApiAuth<TenantIntegrationRow>(
    auth,
    "integrations",
    "update_integration",
    payload,
  );
}

export async function disconnectIntegration(
  auth: AuthContext,
  input: DisconnectIntegrationRequest,
): Promise<{ disconnected: true; provider_code: string }> {
  return await callModuleApiAuth(auth, "integrations", "disconnect_integration", {
    provider_code: input.provider_code,
  });
}

export async function listWebhookDefinitions(
  auth: AuthContext,
  providerCode?: string,
): Promise<WebhookDefinitionRow[]> {
  return await callModuleApiAuth<WebhookDefinitionRow[]>(
    auth,
    "integrations",
    "list_webhook_definitions",
    providerCode ? { provider_code: providerCode } : {},
  );
}

export async function createWebhookDefinition(
  auth: AuthContext,
  input: CreateWebhookDefinitionRequest,
): Promise<WebhookDefinitionRow> {
  const payload: Record<string, unknown> = {
    provider_code: input.provider_code,
    event_type: input.event_type,
    target_url: input.target_url,
    is_active: input.is_active ?? true,
  };
  if (input.signing_secret_ref !== undefined) {
    payload.signing_secret_ref = input.signing_secret_ref;
  }

  return await callModuleApiAuth<WebhookDefinitionRow>(
    auth,
    "integrations",
    "create_webhook_definition",
    payload,
  );
}

export async function updateWebhookDefinition(
  auth: AuthContext,
  input: UpdateWebhookDefinitionRequest,
): Promise<WebhookDefinitionRow> {
  const payload: Record<string, unknown> = { id: input.id };
  if (input.event_type !== undefined) payload.event_type = input.event_type;
  if (input.target_url !== undefined) payload.target_url = input.target_url;
  if (input.signing_secret_ref !== undefined) {
    payload.signing_secret_ref = input.signing_secret_ref;
  }
  if (input.is_active !== undefined) payload.is_active = input.is_active;

  return await callModuleApiAuth<WebhookDefinitionRow>(
    auth,
    "integrations",
    "update_webhook_definition",
    payload,
  );
}

export async function deleteWebhookDefinition(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  return await callModuleApiAuth(auth, "integrations", "delete_webhook_definition", { id });
}

export async function listDeviceMaps(
  auth: AuthContext,
  deviceId?: string,
  providerCode?: string,
): Promise<DeviceIntegrationMapRow[]> {
  const payload: Record<string, string> = {};
  if (deviceId) payload.device_id = deviceId;
  if (providerCode) payload.provider_code = providerCode;

  return await callModuleApiAuth<DeviceIntegrationMapRow[]>(
    auth,
    "integrations",
    "list_device_maps",
    payload,
  );
}

export async function createDeviceMap(
  auth: AuthContext,
  input: CreateDeviceMapRequest,
): Promise<DeviceIntegrationMapRow> {
  return await callModuleApiAuth<DeviceIntegrationMapRow>(
    auth,
    "integrations",
    "create_device_map",
    {
      device_id: input.device_id,
      provider_code: input.provider_code,
      external_id: input.external_id,
      config: input.config ?? {},
    },
  );
}

export async function updateDeviceMap(
  auth: AuthContext,
  input: UpdateDeviceMapRequest,
): Promise<DeviceIntegrationMapRow> {
  const payload: Record<string, unknown> = { id: input.id };
  if (input.external_id !== undefined) payload.external_id = input.external_id;
  if (input.config !== undefined) payload.config = input.config;

  return await callModuleApiAuth<DeviceIntegrationMapRow>(
    auth,
    "integrations",
    "update_device_map",
    payload,
  );
}

export async function deleteDeviceMap(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  return await callModuleApiAuth(auth, "integrations", "delete_device_map", { id });
}

export async function startOAuth(
  auth: AuthContext,
  input: OAuthStartRequest,
): Promise<OAuthStartResponse> {
  const payload: Record<string, unknown> = {
    provider_code: input.provider_code,
  };
  if (input.redirect_uri !== undefined) {
    payload.redirect_uri = input.redirect_uri;
  }

  return await callModuleApiAuth<OAuthStartResponse>(
    auth,
    "integrations",
    "start_oauth",
    payload,
  );
}

export async function completeOAuthCallback(
  code: string,
  state: string,
): Promise<TenantIntegrationRow> {
  return await callModuleApiService<TenantIntegrationRow>("integrations", "oauth_complete", {
    code,
    state_token: state,
  });
}

export async function syncIntegration(
  auth: AuthContext,
  input: SyncIntegrationRequest,
): Promise<SyncIntegrationResponse> {
  return await callModuleApiAuth<SyncIntegrationResponse>(
    auth,
    "integrations",
    "request_sync",
    {
      provider_code: input.provider_code,
      scope: input.scope ?? {},
    },
  );
}
