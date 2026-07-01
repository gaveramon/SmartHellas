import { ValidationError } from "../shared/errors.ts";
import { optionalEnum } from "../shared/validation.ts";
import type {
  CreateAccessPolicyRequest,
  CreateAccessRuleRequest,
  CreateBookingAccessRequest,
  CreateBookingRequest,
  UpdateAccessPolicyRequest,
  UpdateAccessRuleRequest,
  UpdateBookingRequest,
  UpsertAccessScheduleRequest,
} from "./types.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^\d{2}:\d{2}(:\d{2})?$/;

export const BOOKING_STATUSES = [
  "pending",
  "confirmed",
  "checked_in",
  "checked_out",
  "cancelled",
] as const;

export const ACCESS_TYPES_NON_GUEST = [
  "owner",
  "temporary",
  "emergency",
  "scheduled",
] as const;

export const ACCESS_RULE_TYPES = ["override", "emergency_access"] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("booking");
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

export function parseCreateBookingBody(body: unknown): CreateBookingRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const startDate = r.start_date;
  const endDate = r.end_date;
  if (typeof startDate !== "string" || !DATE_RE.test(startDate)) {
    throw new ValidationError("start_date must be YYYY-MM-DD");
  }
  if (typeof endDate !== "string" || !DATE_RE.test(endDate)) {
    throw new ValidationError("end_date must be YYYY-MM-DD");
  }
  const result: CreateBookingRequest = {
    property_id: requireUuidField(r, "property_id"),
    start_date: startDate,
    end_date: endDate,
  };
  if (r.guest_name !== undefined && r.guest_name !== null) {
    result.guest_name = String(r.guest_name);
  }
  if (r.guest_email !== undefined && r.guest_email !== null) {
    result.guest_email = String(r.guest_email);
  }
  const status = optionalEnum(r.status, "status", BOOKING_STATUSES);
  if (status) result.status = status;
  return result;
}

export function parseUpdateBookingBody(body: unknown): UpdateBookingRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateBookingRequest = { id: requireUuidField(r, "id") };
  if (r.guest_name !== undefined) result.guest_name = r.guest_name as string | null;
  if (r.guest_email !== undefined) result.guest_email = r.guest_email as string | null;
  if (r.start_date !== undefined) {
    if (typeof r.start_date !== "string" || !DATE_RE.test(r.start_date)) {
      throw new ValidationError("start_date must be YYYY-MM-DD");
    }
    result.start_date = r.start_date;
  }
  if (r.end_date !== undefined) {
    if (typeof r.end_date !== "string" || !DATE_RE.test(r.end_date)) {
      throw new ValidationError("end_date must be YYYY-MM-DD");
    }
    result.end_date = r.end_date;
  }
  const status = optionalEnum(r.status, "status", BOOKING_STATUSES);
  if (status) result.status = status;
  if (
    result.guest_name === undefined &&
    result.guest_email === undefined &&
    !result.start_date &&
    !result.end_date &&
    !result.status
  ) {
    throw new ValidationError("At least one booking field is required");
  }
  return result;
}

export function parseUpsertAccessScheduleBody(
  body: unknown,
): UpsertAccessScheduleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpsertAccessScheduleRequest = {
    property_id: requireUuidField(r, "property_id"),
  };
  if (r.check_in_time !== undefined) {
    if (typeof r.check_in_time !== "string" || !TIME_RE.test(r.check_in_time)) {
      throw new ValidationError("check_in_time must be HH:MM or HH:MM:SS");
    }
    result.check_in_time = r.check_in_time;
  }
  if (r.check_out_time !== undefined) {
    if (typeof r.check_out_time !== "string" || !TIME_RE.test(r.check_out_time)) {
      throw new ValidationError("check_out_time must be HH:MM or HH:MM:SS");
    }
    result.check_out_time = r.check_out_time;
  }
  if (r.early_check_in_minutes !== undefined) {
    if (typeof r.early_check_in_minutes !== "number" || r.early_check_in_minutes < 0) {
      throw new ValidationError("early_check_in_minutes must be a non-negative number");
    }
    result.early_check_in_minutes = r.early_check_in_minutes;
  }
  if (r.late_checkout_minutes !== undefined) {
    if (typeof r.late_checkout_minutes !== "number" || r.late_checkout_minutes < 0) {
      throw new ValidationError("late_checkout_minutes must be a non-negative number");
    }
    result.late_checkout_minutes = r.late_checkout_minutes;
  }
  if (r.is_active !== undefined) {
    if (typeof r.is_active !== "boolean") {
      throw new ValidationError("is_active must be a boolean");
    }
    result.is_active = r.is_active;
  }
  return result;
}

export function parseCreateBookingAccessBody(
  body: unknown,
): CreateBookingAccessRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateBookingAccessRequest = {
    booking_id: requireUuidField(r, "booking_id"),
  };
  if (r.valid_from !== undefined) {
    if (typeof r.valid_from !== "string" || !r.valid_from.trim()) {
      throw new ValidationError("valid_from must be a non-empty ISO timestamp");
    }
    result.valid_from = r.valid_from;
  }
  if (r.valid_until !== undefined) {
    if (typeof r.valid_until !== "string" || !r.valid_until.trim()) {
      throw new ValidationError("valid_until must be a non-empty ISO timestamp");
    }
    result.valid_until = r.valid_until;
  }
  if (
    (result.valid_from !== undefined && result.valid_until === undefined) ||
    (result.valid_from === undefined && result.valid_until !== undefined)
  ) {
    throw new ValidationError("valid_from and valid_until must both be provided or omitted");
  }
  return result;
}

export function parseCreateAccessPolicyBody(
  body: unknown,
): CreateAccessPolicyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const accessType = optionalEnum(r.access_type, "access_type", ACCESS_TYPES_NON_GUEST);
  if (!accessType) {
    throw new ValidationError("access_type is required (non-guest types only)");
  }
  const validFrom = r.valid_from;
  const validUntil = r.valid_until;
  if (typeof validFrom !== "string") throw new ValidationError("valid_from required");
  if (typeof validUntil !== "string") throw new ValidationError("valid_until required");
  const result: CreateAccessPolicyRequest = {
    property_id: requireUuidField(r, "property_id"),
    access_type: accessType,
    valid_from: validFrom,
    valid_until: validUntil,
  };
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateAccessPolicyBody(
  body: unknown,
): UpdateAccessPolicyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateAccessPolicyRequest = { id: requireUuidField(r, "id") };
  const accessType = optionalEnum(r.access_type, "access_type", ACCESS_TYPES_NON_GUEST);
  if (accessType) result.access_type = accessType;
  if (r.valid_from !== undefined) result.valid_from = String(r.valid_from);
  if (r.valid_until !== undefined) result.valid_until = String(r.valid_until);
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateAccessRuleBody(body: unknown): CreateAccessRuleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const ruleType = optionalEnum(r.rule_type, "rule_type", ACCESS_RULE_TYPES);
  if (!ruleType) throw new ValidationError("rule_type is required");
  const result: CreateAccessRuleRequest = {
    property_id: requireUuidField(r, "property_id"),
    rule_type: ruleType,
  };
  if (r.rule_config !== undefined) {
    if (typeof r.rule_config !== "object" || Array.isArray(r.rule_config)) {
      throw new ValidationError("rule_config must be an object");
    }
    result.rule_config = r.rule_config as Record<string, unknown>;
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateAccessRuleBody(body: unknown): UpdateAccessRuleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateAccessRuleRequest = { id: requireUuidField(r, "id") };
  const ruleType = optionalEnum(r.rule_type, "rule_type", ACCESS_RULE_TYPES);
  if (ruleType) result.rule_type = ruleType;
  if (r.rule_config !== undefined) {
    result.rule_config = r.rule_config as Record<string, unknown> | null;
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseDeleteIdBody(body: unknown, field = "id"): string {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return requireUuidField(body as Record<string, unknown>, field);
}
