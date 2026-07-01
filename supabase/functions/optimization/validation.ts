import { ValidationError } from "../shared/errors.ts";
import { optionalEnum } from "../shared/validation.ts";
import type {
  CreateOptimizationRuleRequest,
  UpdateOptimizationRuleRequest,
  UpdateRecommendationRequest,
} from "./types.ts";

export { optionalEnumQuery } from "../shared/validation.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const OPTIMIZATION_CATEGORIES = [
  "energy",
  "security",
  "cost",
  "efficiency",
  "performance",
  "user_experience",
] as const;

export const RECOMMENDATION_SEVERITIES = ["low", "medium", "high"] as const;

export const RECOMMENDATION_STATUSES = [
  "open",
  "acknowledged",
  "dismissed",
  "converted_to_proposal",
  "implemented",
] as const;

export const OPTIMIZATION_INSIGHT_TYPES = [
  "anomaly_detected",
  "optimization_opportunity",
  "usage_pattern",
] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("optimization");
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

function requireStringField(record: Record<string, unknown>, field: string): string {
  const value = record[field];
  if (typeof value !== "string" || !value.trim()) {
    throw new ValidationError(`${field} is required`, { field });
  }
  return value.trim();
}

function requireJsonObject(value: unknown, field: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new ValidationError(`${field} must be a JSON object`, { field });
  }
  return value as Record<string, unknown>;
}

export function parseDeleteIdBody(body: unknown): string {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return requireUuidField(body as Record<string, unknown>, "id");
}

export function parseCreateRuleBody(body: unknown): CreateOptimizationRuleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateOptimizationRuleRequest = {
    rule_name: requireStringField(r, "rule_name"),
    rule_config: requireJsonObject(r.rule_config, "rule_config"),
  };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.category !== undefined) {
    result.category = optionalEnum(r.category, "category", OPTIMIZATION_CATEGORIES);
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateRuleBody(body: unknown): UpdateOptimizationRuleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateOptimizationRuleRequest = { id: requireUuidField(r, "id") };
  if (r.rule_name !== undefined) result.rule_name = String(r.rule_name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.category !== undefined) {
    result.category =
      r.category === null
        ? null
        : optionalEnum(r.category, "category", OPTIMIZATION_CATEGORIES);
  }
  if (r.rule_config !== undefined) result.rule_config = requireJsonObject(r.rule_config, "rule_config");
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateRecommendationBody(body: unknown): UpdateRecommendationRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateRecommendationRequest = { id: requireUuidField(r, "id") };
  if (r.status !== undefined) {
    const status = optionalEnum(r.status, "status", RECOMMENDATION_STATUSES);
    if (!status) throw new ValidationError("status is required");
    result.status = status;
  }
  if (!result.status) {
    throw new ValidationError("status is required");
  }
  return result;
}
