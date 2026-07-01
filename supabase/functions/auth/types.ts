export interface AuthContextResponse {
  user_id: string;
  email: string | null;
  tenant_id: string | null;
  role: string | null;
  tenant_status: string | null;
  is_platform_admin: boolean;
}

export interface TenantListItem {
  tenant_id: string;
  tenant_name: string;
  role: string;
  is_active: boolean;
  tenant_status: string;
}

export interface TenantDetail {
  id: string;
  name: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface SwitchTenantRequest {
  tenant_id: string;
}

export interface SwitchTenantResponse {
  tenant_id: string;
  role: string;
}

export interface CreateTenantRequest {
  name: string;
}

export interface UpdateTenantRequest {
  name?: string;
  status?: string;
}

export interface MembershipListItem {
  id: string;
  user_id: string;
  tenant_id: string;
  role: string;
  is_active: boolean;
  revoked_at: string | null;
  email: string | null;
  full_name: string | null;
  created_at: string;
}

export interface InviteMemberRequest {
  email: string;
  role: string;
}

export interface UpdateMembershipRequest {
  membership_id: string;
  role?: string;
  is_active?: boolean;
}

export interface RevokeMembershipRequest {
  membership_id: string;
}

export interface SubscriptionDetail {
  id: string;
  tenant_id: string;
  tier: string;
  status: string;
  current_period_start: string | null;
  current_period_end: string | null;
  created_at: string;
  updated_at: string;
}

export interface UpdateSubscriptionRequest {
  tier?: string;
  status?: string;
  current_period_start?: string;
  current_period_end?: string;
}

export interface ServiceAccountRow {
  id: string;
  tenant_id: string;
  name: string;
  provider_code: string | null;
  is_active: boolean;
  created_at: string;
}

export interface CreateServiceAccountRequest {
  name: string;
  provider_code?: string;
  is_active?: boolean;
}

export interface UpdateServiceAccountRequest {
  service_account_id: string;
  name?: string;
  provider_code?: string;
  is_active?: boolean;
}

export interface DeleteServiceAccountRequest {
  service_account_id: string;
}

export type AuthRoute =
  | "context"
  | "tenants"
  | "switch-tenant"
  | "tenant"
  | "tenant-create"
  | "memberships"
  | "subscription"
  | "service-accounts";
