export interface TenantPortalSettingsRow {
  id: string;
  tenant_id: string;
  theme: Record<string, unknown> | null;
  default_language: string;
  created_at: string;
  updated_at: string;
}

export interface DashboardConfigRow {
  id: string;
  tenant_id: string;
  name: string;
  layout: Record<string, unknown> | null;
  is_default: boolean;
  created_at: string;
}

export interface PortalUserPreferenceRow {
  id: string;
  tenant_id: string;
  user_id: string;
  preference_key: string;
  value: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface PortalFeatureFlagRow {
  id: string;
  tenant_id: string;
  feature_key: string;
  enabled: boolean;
  created_at: string;
}

export interface PortalBootstrapResponse {
  settings: TenantPortalSettingsRow | null;
  default_dashboard: DashboardConfigRow | null;
  feature_flags: PortalFeatureFlagRow[];
}

export interface UpsertPortalSettingsRequest {
  theme?: Record<string, unknown> | null;
  default_language?: string;
}

export interface CreateDashboardRequest {
  name: string;
  layout?: Record<string, unknown>;
  is_default?: boolean;
}

export interface UpdateDashboardRequest {
  id: string;
  name?: string;
  layout?: Record<string, unknown> | null;
  is_default?: boolean;
}

export interface UpsertPreferenceRequest {
  preference_key: string;
  value: Record<string, unknown>;
}

export interface UpdatePreferenceRequest {
  preference_key: string;
  value?: Record<string, unknown>;
}

export interface CreateFeatureFlagRequest {
  feature_key: string;
  enabled?: boolean;
}

export interface UpdateFeatureFlagRequest {
  id: string;
  feature_key?: string;
  enabled?: boolean;
}
