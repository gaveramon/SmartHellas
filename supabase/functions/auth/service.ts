import { type AuthContext } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  AuthContextResponse,
  CreateServiceAccountRequest,
  CreateTenantRequest,
  MembershipListItem,
  ServiceAccountRow,
  SubscriptionDetail,
  SwitchTenantRequest,
  SwitchTenantResponse,
  TenantDetail,
  TenantListItem,
  UpdateMembershipRequest,
  UpdateServiceAccountRequest,
  UpdateSubscriptionRequest,
  UpdateTenantRequest,
} from "./types.ts";

export async function getAuthContext(
  auth: AuthContext,
): Promise<AuthContextResponse> {
  return await callModuleApiAuth<AuthContextResponse>(auth, "auth", "get_auth_context");
}

export async function listUserTenants(
  auth: AuthContext,
): Promise<TenantListItem[]> {
  return await callModuleApiAuth<TenantListItem[]>(auth, "auth", "list_user_tenants");
}

export async function switchTenant(
  auth: AuthContext,
  input: SwitchTenantRequest,
): Promise<SwitchTenantResponse> {
  return await callModuleApiAuth<SwitchTenantResponse>(auth, "auth", "switch_tenant", {
    tenant_id: input.tenant_id,
  });
}

export async function getCurrentTenant(auth: AuthContext): Promise<TenantDetail> {
  return await callModuleApiAuth<TenantDetail>(auth, "auth", "get_current_tenant");
}

export async function createTenant(
  auth: AuthContext,
  input: CreateTenantRequest,
): Promise<TenantDetail> {
  return await callModuleApiAuth<TenantDetail>(auth, "auth", "create_tenant", {
    name: input.name,
  });
}

export async function updateTenant(
  auth: AuthContext,
  input: UpdateTenantRequest,
): Promise<TenantDetail> {
  const payload: Record<string, unknown> = {};
  if (input.name !== undefined) payload.name = input.name;
  if (input.status !== undefined) payload.status = input.status;

  return await callModuleApiAuth<TenantDetail>(auth, "auth", "update_tenant", payload);
}

export async function listMemberships(
  auth: AuthContext,
): Promise<MembershipListItem[]> {
  return await callModuleApiAuth<MembershipListItem[]>(auth, "auth", "list_memberships");
}

export async function inviteMember(
  auth: AuthContext,
  email: string,
  role: string,
): Promise<MembershipListItem> {
  return await callModuleApiAuth<MembershipListItem>(auth, "auth", "invite_member", {
    email,
    role,
  });
}

export async function updateMembership(
  auth: AuthContext,
  input: UpdateMembershipRequest,
): Promise<MembershipListItem> {
  const payload: Record<string, unknown> = {
    membership_id: input.membership_id,
  };
  if (input.role !== undefined) payload.role = input.role;
  if (input.is_active !== undefined) payload.is_active = input.is_active;

  return await callModuleApiAuth<MembershipListItem>(
    auth,
    "auth",
    "update_membership",
    payload,
  );
}

export async function revokeMembership(
  auth: AuthContext,
  membershipId: string,
): Promise<{ revoked: true; membership_id: string }> {
  return await callModuleApiAuth(auth, "auth", "revoke_membership", {
    membership_id: membershipId,
  });
}

export async function getSubscription(
  auth: AuthContext,
): Promise<SubscriptionDetail | null> {
  return await callModuleApiAuth<SubscriptionDetail | null>(
    auth,
    "auth",
    "get_subscription",
  );
}

export async function updateSubscription(
  auth: AuthContext,
  input: UpdateSubscriptionRequest,
): Promise<SubscriptionDetail> {
  const payload: Record<string, unknown> = {};
  if (input.tier !== undefined) payload.tier = input.tier;
  if (input.status !== undefined) payload.status = input.status;
  if (input.current_period_start !== undefined) {
    payload.current_period_start = input.current_period_start;
  }
  if (input.current_period_end !== undefined) {
    payload.current_period_end = input.current_period_end;
  }

  return await callModuleApiAuth<SubscriptionDetail>(
    auth,
    "auth",
    "update_subscription",
    payload,
  );
}

export async function listServiceAccounts(
  auth: AuthContext,
): Promise<ServiceAccountRow[]> {
  return await callModuleApiAuth<ServiceAccountRow[]>(
    auth,
    "auth",
    "list_service_accounts",
  );
}

export async function createServiceAccount(
  auth: AuthContext,
  input: CreateServiceAccountRequest,
): Promise<ServiceAccountRow> {
  const payload: Record<string, unknown> = { name: input.name };
  if (input.provider_code !== undefined) payload.provider_code = input.provider_code;
  if (input.is_active !== undefined) payload.is_active = input.is_active;

  return await callModuleApiAuth<ServiceAccountRow>(
    auth,
    "auth",
    "create_service_account",
    payload,
  );
}

export async function updateServiceAccount(
  auth: AuthContext,
  input: UpdateServiceAccountRequest,
): Promise<ServiceAccountRow> {
  const payload: Record<string, unknown> = {
    service_account_id: input.service_account_id,
  };
  if (input.name !== undefined) payload.name = input.name;
  if (input.provider_code !== undefined) payload.provider_code = input.provider_code;
  if (input.is_active !== undefined) payload.is_active = input.is_active;

  return await callModuleApiAuth<ServiceAccountRow>(
    auth,
    "auth",
    "update_service_account",
    payload,
  );
}

export async function deleteServiceAccount(
  auth: AuthContext,
  serviceAccountId: string,
): Promise<{ deleted: true; service_account_id: string }> {
  return await callModuleApiAuth(auth, "auth", "delete_service_account", {
    service_account_id: serviceAccountId,
  });
}
