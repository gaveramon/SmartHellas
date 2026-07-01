export interface BookingRow {
  id: string;
  tenant_id: string;
  property_id: string;
  guest_name: string | null;
  guest_email: string | null;
  start_date: string;
  end_date: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface PropertyAccessScheduleRow {
  id: string;
  tenant_id: string;
  property_id: string;
  check_in_time: string;
  check_out_time: string;
  early_check_in_minutes: number;
  late_checkout_minutes: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface BookingAccessRow {
  id: string;
  tenant_id: string;
  booking_id: string;
  access_type: string;
  valid_from: string;
  valid_until: string;
  created_at: string;
  updated_at: string;
}

export interface AccessPolicyRow {
  id: string;
  tenant_id: string;
  property_id: string;
  access_type: string;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface AccessRuleRow {
  id: string;
  tenant_id: string;
  property_id: string;
  rule_type: string;
  rule_config: Record<string, unknown> | null;
  is_active: boolean;
  created_at: string;
}

export interface CreateBookingRequest {
  property_id: string;
  guest_name?: string;
  guest_email?: string;
  start_date: string;
  end_date: string;
  status?: string;
}

export interface UpdateBookingRequest {
  id: string;
  guest_name?: string | null;
  guest_email?: string | null;
  start_date?: string;
  end_date?: string;
  status?: string;
}

export interface UpsertAccessScheduleRequest {
  property_id: string;
  check_in_time?: string;
  check_out_time?: string;
  early_check_in_minutes?: number;
  late_checkout_minutes?: number;
  is_active?: boolean;
}

export interface CreateBookingAccessRequest {
  booking_id: string;
  /** @deprecated Manual windows bypass computed SSOT; use booking_id only. */
  valid_from?: string;
  /** @deprecated Manual windows bypass computed SSOT; use booking_id only. */
  valid_until?: string;
}

export interface CreateAccessPolicyRequest {
  property_id: string;
  access_type: string;
  valid_from: string;
  valid_until: string;
  is_active?: boolean;
}

export interface UpdateAccessPolicyRequest {
  id: string;
  access_type?: string;
  valid_from?: string;
  valid_until?: string;
  is_active?: boolean;
}

export interface CreateAccessRuleRequest {
  property_id: string;
  rule_type: string;
  rule_config?: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateAccessRuleRequest {
  id: string;
  rule_type?: string;
  rule_config?: Record<string, unknown> | null;
  is_active?: boolean;
}
