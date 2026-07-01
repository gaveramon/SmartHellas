import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  CreateDashboardRequest,
  CreateFeatureFlagRequest,
  DashboardConfigRow,
  PortalBootstrapResponse,
  PortalFeatureFlagRow,
  PortalUserPreferenceRow,
  TenantPortalSettingsRow,
  UpdateDashboardRequest,
  UpdateFeatureFlagRequest,
  UpdatePreferenceRequest,
  UpsertPortalSettingsRequest,
  UpsertPreferenceRequest,
} from "./types.ts";

function tid(auth: AuthContext): string {
  return requireTenant(auth);
}

export async function getPortalBootstrap(
  auth: AuthContext,
): Promise<PortalBootstrapResponse> {
  tid(auth);
  return await callModuleApiAuth<PortalBootstrapResponse>(auth, "portal", "get_portal_bootstrap");
}

export async function getPortalSettings(
  auth: AuthContext,
): Promise<TenantPortalSettingsRow | null> {
  tid(auth);
  return await callModuleApiAuth<TenantPortalSettingsRow | null>(
    auth,
    "portal",
    "get_portal_settings",
  );
}

export async function upsertPortalSettings(
  auth: AuthContext,
  input: UpsertPortalSettingsRequest,
): Promise<TenantPortalSettingsRow> {
  return await callModuleApiAuth<TenantPortalSettingsRow>(
    auth,
    "portal",
    "upsert_portal_settings",
    { ...input },
  );
}

export async function listDashboards(auth: AuthContext): Promise<DashboardConfigRow[]> {
  tid(auth);
  return await callModuleApiAuth<DashboardConfigRow[]>(auth, "portal", "list_dashboards");
}

export async function getDashboard(auth: AuthContext, id: string): Promise<DashboardConfigRow> {
  tid(auth);
  return await callModuleApiAuth<DashboardConfigRow>(auth, "portal", "get_dashboard", { id });
}

export async function createDashboard(
  auth: AuthContext,
  input: CreateDashboardRequest,
): Promise<DashboardConfigRow> {
  return await callModuleApiAuth<DashboardConfigRow>(auth, "portal", "create_dashboard", { ...input });
}

export async function updateDashboard(
  auth: AuthContext,
  input: UpdateDashboardRequest,
): Promise<DashboardConfigRow> {
  return await callModuleApiAuth<DashboardConfigRow>(auth, "portal", "update_dashboard", { ...input });
}

export async function deleteDashboard(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "portal", "delete_dashboard", { id });
}

export async function listUserPreferences(
  auth: AuthContext,
): Promise<PortalUserPreferenceRow[]> {
  tid(auth);
  return await callModuleApiAuth<PortalUserPreferenceRow[]>(
    auth,
    "portal",
    "list_user_preferences",
  );
}

export async function getUserPreference(
  auth: AuthContext,
  preferenceKey: string,
): Promise<PortalUserPreferenceRow | null> {
  tid(auth);
  return await callModuleApiAuth<PortalUserPreferenceRow | null>(
    auth,
    "portal",
    "get_user_preference",
    { preference_key: preferenceKey },
  );
}

export async function upsertUserPreference(
  auth: AuthContext,
  input: UpsertPreferenceRequest,
): Promise<PortalUserPreferenceRow> {
  return await callModuleApiAuth<PortalUserPreferenceRow>(
    auth,
    "portal",
    "upsert_user_preference",
    { ...input },
  );
}

export async function updateUserPreference(
  auth: AuthContext,
  input: UpdatePreferenceRequest,
): Promise<PortalUserPreferenceRow> {
  return await callModuleApiAuth<PortalUserPreferenceRow>(
    auth,
    "portal",
    "update_user_preference",
    { ...input },
  );
}

export async function deleteUserPreference(
  auth: AuthContext,
  preferenceKey: string,
): Promise<{ deleted: true; preference_key: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "portal", "delete_user_preference", {
    preference_key: preferenceKey,
  });
}

export async function listFeatureFlags(
  auth: AuthContext,
): Promise<PortalFeatureFlagRow[]> {
  tid(auth);
  return await callModuleApiAuth<PortalFeatureFlagRow[]>(auth, "portal", "list_feature_flags");
}

export async function createFeatureFlag(
  auth: AuthContext,
  input: CreateFeatureFlagRequest,
): Promise<PortalFeatureFlagRow> {
  return await callModuleApiAuth<PortalFeatureFlagRow>(
    auth,
    "portal",
    "create_feature_flag",
    { ...input },
  );
}

export async function updateFeatureFlag(
  auth: AuthContext,
  input: UpdateFeatureFlagRequest,
): Promise<PortalFeatureFlagRow> {
  return await callModuleApiAuth<PortalFeatureFlagRow>(
    auth,
    "portal",
    "update_feature_flag",
    { ...input },
  );
}

export async function deleteFeatureFlag(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "portal", "delete_feature_flag", { id });
}
