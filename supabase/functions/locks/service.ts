import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  AccessCredentialRow,
  CreateLockDeviceRequest,
  IssueCredentialRequest,
  IssueCredentialResponse,
  LockDeviceRow,
  RevokeCredentialRequest,
  UpdateLockDeviceRequest,
} from "./types.ts";

function tid(auth: AuthContext): string {
  return requireTenant(auth);
}

export async function listLockDevices(
  auth: AuthContext,
  propertyId?: string,
): Promise<LockDeviceRow[]> {
  tid(auth);
  return await callModuleApiAuth<LockDeviceRow[]>(
    auth,
    "locks",
    "list_lock_devices",
    propertyId ? { property_id: propertyId } : {},
  );
}

export async function getLockDevice(auth: AuthContext, id: string): Promise<LockDeviceRow> {
  tid(auth);
  return await callModuleApiAuth<LockDeviceRow>(auth, "locks", "get_lock_device", { id });
}

export async function createLockDevice(
  auth: AuthContext,
  input: CreateLockDeviceRequest,
): Promise<LockDeviceRow> {
  return await callModuleApiAuth<LockDeviceRow>(auth, "locks", "create_lock_device", { ...input });
}

export async function updateLockDevice(
  auth: AuthContext,
  input: UpdateLockDeviceRequest,
): Promise<LockDeviceRow> {
  return await callModuleApiAuth<LockDeviceRow>(auth, "locks", "update_lock_device", { ...input });
}

export async function deleteLockDevice(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "locks", "delete_lock_device", { id });
}

export async function listCredentials(
  auth: AuthContext,
  bookingId?: string,
): Promise<AccessCredentialRow[]> {
  tid(auth);
  return await callModuleApiAuth<AccessCredentialRow[]>(
    auth,
    "locks",
    "list_credentials",
    bookingId ? { booking_id: bookingId } : {},
  );
}

export async function getCredential(
  auth: AuthContext,
  id: string,
): Promise<AccessCredentialRow> {
  tid(auth);
  return await callModuleApiAuth<AccessCredentialRow>(auth, "locks", "get_credential", { id });
}

export async function issueCredential(
  auth: AuthContext,
  input: IssueCredentialRequest,
): Promise<IssueCredentialResponse> {
  return await callModuleApiAuth<IssueCredentialResponse>(
    auth,
    "locks",
    "issue_credential",
    { ...input },
  );
}

export async function revokeCredential(
  auth: AuthContext,
  input: RevokeCredentialRequest,
): Promise<{ credential: AccessCredentialRow }> {
  return await callModuleApiAuth<{ credential: AccessCredentialRow }>(
    auth,
    "locks",
    "revoke_credential",
    { ...input },
  );
}
