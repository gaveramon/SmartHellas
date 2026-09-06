import { ValidationError } from "../shared/errors.ts";
import type {
  CreateLockDeviceRequest,
  IssueCredentialRequest,
  RevokeCredentialRequest,
  UpdateLockDeviceRequest,
} from "./types.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("locks");
  if (idx >= 0 && segments.length > idx + 1) {
    return segments[idx + 1];
  }
  return segments[segments.length - 1] ?? "";
}

export function parseUuidQuery(req: Request, param = "id"): string {
  const value = new URL(req.url).searchParams.get(param);
  if (!value || !isUuid(value)) {
    throw new ValidationError(`${param} must be a valid UUID`, { field: param });
  }
  return value;
}

export function optionalUuidQuery(req: Request, param: string): string | undefined {
  const value = new URL(req.url).searchParams.get(param);
  if (!value) return undefined;
  if (!isUuid(value)) {
    throw new ValidationError(`${param} must be a valid UUID`, { field: param });
  }
  return value;
}

function requireUuidField(record: Record<string, unknown>, field: string): string {
  const value = record[field];
  if (typeof value !== "string" || !isUuid(value)) {
    throw new ValidationError(`${field} must be a valid UUID`, { field });
  }
  return value;
}

export function parseCreateLockDeviceBody(body: unknown): CreateLockDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateLockDeviceRequest = {
    device_id: requireUuidField(r, "device_id"),
    property_id: requireUuidField(r, "property_id"),
  };
  if (r.is_primary !== undefined) {
    if (typeof r.is_primary !== "boolean") {
      throw new ValidationError("is_primary must be a boolean");
    }
    result.is_primary = r.is_primary;
  }
  return result;
}

export function parseUpdateLockDeviceBody(body: unknown): UpdateLockDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateLockDeviceRequest = { id: requireUuidField(r, "id") };
  if (r.is_primary !== undefined) {
    if (typeof r.is_primary !== "boolean") {
      throw new ValidationError("is_primary must be a boolean");
    }
    result.is_primary = r.is_primary;
  }
  return result;
}

export function parseIssueCredentialBody(body: unknown): IssueCredentialRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const credentialRef = r.credential_ref;
  if (typeof credentialRef !== "string" || !credentialRef.trim()) {
    throw new ValidationError(
      "credential_ref is required (vault secret name — never a plaintext code)",
    );
  }
  const result: IssueCredentialRequest = {
    booking_id: requireUuidField(r, "booking_id"),
    lock_device_id: requireUuidField(r, "lock_device_id"),
    credential_ref: credentialRef.trim(),
  };
  if (r.booking_access_id !== undefined && r.booking_access_id !== null) {
    result.booking_access_id = requireUuidField(
      { booking_access_id: r.booking_access_id },
      "booking_access_id",
    );
  }
  if (r.valid_from !== undefined) result.valid_from = String(r.valid_from);
  if (r.valid_until !== undefined) result.valid_until = String(r.valid_until);
  if (r.idempotency_key !== undefined) {
    result.idempotency_key = String(r.idempotency_key);
  }
  return result;
}

export function parseRevokeCredentialBody(body: unknown): RevokeCredentialRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: RevokeCredentialRequest = {
    credential_id: requireUuidField(r, "credential_id"),
  };
  if (r.idempotency_key !== undefined) {
    result.idempotency_key = String(r.idempotency_key);
  }
  return result;
}

export function parseDeleteIdBody(body: unknown): string {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return requireUuidField(body as Record<string, unknown>, "id");
}
