import { ValidationError } from "./errors.ts";

export const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** 001 SSOT subscription_tier labels — validation only, rules enforced in SQL. */
export const SUBSCRIPTION_TIERS = ["basic", "pro", "enterprise"] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function requireUuidField(
  record: Record<string, unknown>,
  field: string,
): string {
  const value = record[field];
  if (typeof value !== "string" || !isUuid(value)) {
    throw new ValidationError(`${field} must be a valid UUID`, { field });
  }
  return value;
}

export function optionalEnum<T extends string>(
  value: unknown,
  field: string,
  allowed: readonly T[],
): T | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string" || !allowed.includes(value as T)) {
    throw new ValidationError(`${field} must be one of: ${allowed.join(", ")}`, {
      field,
    });
  }
  return value as T;
}

export function requireEnum<T extends string>(
  value: unknown,
  field: string,
  allowed: readonly T[],
): T {
  const parsed = optionalEnum(value, field, allowed);
  if (!parsed) {
    throw new ValidationError(`${field} is required`, { field });
  }
  return parsed;
}

export function optionalEnumQuery<T extends string>(
  req: Request,
  param: string,
  allowed: readonly T[],
): T | undefined {
  const value = new URL(req.url).searchParams.get(param);
  if (!value) return undefined;
  if (!allowed.includes(value as T)) {
    throw new ValidationError(`${param} must be one of: ${allowed.join(", ")}`);
  }
  return value as T;
}
