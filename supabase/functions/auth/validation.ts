import { ValidationError } from "../shared/errors.ts";
import { optionalEnum } from "../shared/validation.ts";
import type {
  CreateServiceAccountRequest,
  CreateTenantRequest,
  DeleteServiceAccountRequest,
  InviteMemberRequest,
  RevokeMembershipRequest,
  SwitchTenantRequest,
  UpdateMembershipRequest,
  UpdateServiceAccountRequest,
  UpdateSubscriptionRequest,
  UpdateTenantRequest,
} from "./types.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** 001 SSOT user_role labels — validation only, rules enforced in SQL. */
export const USER_ROLES = [
  "owner",
  "admin",
  "manager",
  "support",
  "viewer",
] as const;

export const TENANT_STATUSES = ["active", "suspended", "deleted"] as const;

export const SUBSCRIPTION_STATUSES = [
  "trial",
  "pending",
  "active",
  "past_due",
  "suspended",
  "cancelled",
  "expired",
  "trial_expired",
] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

function requireUuidField(
  record: Record<string, unknown>,
  field: string,
): string {
  const value = record[field];
  if (typeof value !== "string" || !isUuid(value)) {
    throw new ValidationError(`${field} must be a valid UUID`, { field });
  }
  return value;
}

export function parseSwitchTenantBody(body: unknown): SwitchTenantRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return { tenant_id: requireUuidField(body as Record<string, unknown>, "tenant_id") };
}

export function parseCreateTenantBody(body: unknown): CreateTenantRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const record = body as Record<string, unknown>;
  const name = record.name;
  if (typeof name !== "string" || name.trim().length < 1 || name.length > 200) {
    throw new ValidationError("name is required (1–200 characters)", {
      field: "name",
    });
  }
  return { name: name.trim() };
}

export function parseUpdateTenantBody(body: unknown): UpdateTenantRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const record = body as Record<string, unknown>;
  const result: UpdateTenantRequest = {};

  if (record.name !== undefined) {
    if (typeof record.name !== "string" || record.name.trim().length < 1) {
      throw new ValidationError("name must be a non-empty string", {
        field: "name",
      });
    }
    result.name = record.name.trim();
  }

  const status = optionalEnum(record.status, "status", TENANT_STATUSES);
  if (status) result.status = status;

  if (!result.name && !result.status) {
    throw new ValidationError("At least one of name or status is required");
  }

  return result;
}

export function parseInviteMemberBody(body: unknown): InviteMemberRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const record = body as Record<string, unknown>;
  const email = record.email;
  if (typeof email !== "string" || !email.includes("@")) {
    throw new ValidationError("email must be a valid email address", {
      field: "email",
    });
  }
  const role = optionalEnum(record.role, "role", USER_ROLES);
  if (!role) {
    throw new ValidationError("role is required", { field: "role" });
  }
  if (role === "owner") {
    throw new ValidationError("Cannot invite members as owner via this endpoint", {
      field: "role",
    });
  }
  return { email: email.trim().toLowerCase(), role };
}

export function parseUpdateMembershipBody(
  body: unknown,
): UpdateMembershipRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const record = body as Record<string, unknown>;
  const membershipId = requireUuidField(record, "membership_id");

  const result: UpdateMembershipRequest = { membership_id: membershipId };

  const role = optionalEnum(record.role, "role", USER_ROLES);
  if (role) result.role = role;

  if (record.is_active !== undefined) {
    if (typeof record.is_active !== "boolean") {
      throw new ValidationError("is_active must be a boolean", {
        field: "is_active",
      });
    }
    result.is_active = record.is_active;
  }

  if (!result.role && result.is_active === undefined) {
    throw new ValidationError("At least one of role or is_active is required");
  }

  return result;
}

export function parseRevokeMembershipBody(
  body: unknown,
): RevokeMembershipRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return {
    membership_id: requireUuidField(body as Record<string, unknown>, "membership_id"),
  };
}

export function parseUpdateSubscriptionBody(
  body: unknown,
): UpdateSubscriptionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const record = body as Record<string, unknown>;
  const result: UpdateSubscriptionRequest = {};

  if (record.tier !== undefined) {
    throw new ValidationError(
      "tier changes must use the commerce change_plan endpoint with plan_id",
      { field: "tier" },
    );
  }

  const status = optionalEnum(record.status, "status", SUBSCRIPTION_STATUSES);
  if (status) result.status = status;

  if (record.current_period_start !== undefined) {
    if (typeof record.current_period_start !== "string") {
      throw new ValidationError("current_period_start must be an ISO timestamp");
    }
    result.current_period_start = record.current_period_start;
  }

  if (record.current_period_end !== undefined) {
    if (typeof record.current_period_end !== "string") {
      throw new ValidationError("current_period_end must be an ISO timestamp");
    }
    result.current_period_end = record.current_period_end;
  }

  if (
    !result.status &&
    !result.current_period_start &&
    !result.current_period_end
  ) {
    throw new ValidationError("At least one subscription field is required");
  }

  return result;
}

export function parseCreateServiceAccountBody(
  body: unknown,
): CreateServiceAccountRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const record = body as Record<string, unknown>;
  const name = record.name;
  if (typeof name !== "string" || name.trim().length < 1) {
    throw new ValidationError("name is required", { field: "name" });
  }

  const result: CreateServiceAccountRequest = { name: name.trim() };

  if (record.provider_code !== undefined && record.provider_code !== null) {
    if (typeof record.provider_code !== "string") {
      throw new ValidationError("provider_code must be a string", {
        field: "provider_code",
      });
    }
    result.provider_code = record.provider_code.trim();
  }

  if (record.is_active !== undefined) {
    if (typeof record.is_active !== "boolean") {
      throw new ValidationError("is_active must be a boolean");
    }
    result.is_active = record.is_active;
  }

  return result;
}

export function parseUpdateServiceAccountBody(
  body: unknown,
): UpdateServiceAccountRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const record = body as Record<string, unknown>;
  const serviceAccountId = requireUuidField(record, "service_account_id");

  const result: UpdateServiceAccountRequest = {
    service_account_id: serviceAccountId,
  };

  if (record.name !== undefined) {
    if (typeof record.name !== "string" || record.name.trim().length < 1) {
      throw new ValidationError("name must be a non-empty string");
    }
    result.name = record.name.trim();
  }

    if (record.provider_code !== undefined) {
      if (record.provider_code !== null && typeof record.provider_code !== "string") {
        throw new ValidationError("provider_code must be a string");
      }
      if (record.provider_code !== null) {
        result.provider_code = record.provider_code;
      }
    }

  if (record.is_active !== undefined) {
    if (typeof record.is_active !== "boolean") {
      throw new ValidationError("is_active must be a boolean");
    }
    result.is_active = record.is_active;
  }

  if (
    !result.name &&
    result.provider_code === undefined &&
    result.is_active === undefined
  ) {
    throw new ValidationError("At least one field is required to update");
  }

  return result;
}

export function parseDeleteServiceAccountBody(
  body: unknown,
): DeleteServiceAccountRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return {
    service_account_id: requireUuidField(
      body as Record<string, unknown>,
      "service_account_id",
    ),
  };
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);

  const authIndex = segments.indexOf("auth");
  if (authIndex >= 0 && segments.length > authIndex + 1) {
    return segments[authIndex + 1];
  }

  return segments[segments.length - 1] ?? "";
}
