export interface LockDeviceRow {
  id: string;
  tenant_id: string;
  device_id: string;
  property_id: string;
  is_primary: boolean;
  created_at: string;
}

export interface AccessCredentialRow {
  id: string;
  tenant_id: string;
  booking_id: string;
  lock_device_id: string;
  booking_access_id: string | null;
  provider_code: string;
  credential_ref: string;
  external_credential_id: string | null;
  status: string;
  valid_from: string;
  valid_until: string;
  revoked_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateLockDeviceRequest {
  device_id: string;
  property_id: string;
  is_primary?: boolean;
}

export interface UpdateLockDeviceRequest {
  id: string;
  is_primary?: boolean;
}

export interface IssueCredentialRequest {
  booking_id: string;
  lock_device_id: string;
  booking_access_id?: string;
  credential_ref: string;
  valid_from?: string;
  valid_until?: string;
  idempotency_key?: string;
}

export interface RevokeCredentialRequest {
  credential_id: string;
  idempotency_key?: string;
}

export interface IssueCredentialResponse {
  credential: AccessCredentialRow;
  command_id: string;
  correlation_id: string;
}
