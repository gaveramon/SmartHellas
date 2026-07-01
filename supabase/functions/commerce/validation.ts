import { ValidationError } from "../shared/errors.ts";
import {
  optionalEnum,
  requireEnum,
  SUBSCRIPTION_TIERS,
} from "../shared/validation.ts";
import type {
  ChangePlanRequest,
  CreateFeatureEntitlementRequest,
  CreatePlanPricingRequest,
  CreateProductPlanRequest,
  CreateUpsellRuleRequest,
  UpdateFeatureEntitlementRequest,
  UpdatePlanPricingRequest,
  UpdateProductPlanRequest,
  UpdateUpsellRuleRequest,
} from "./types.ts";

export { optionalEnumQuery } from "../shared/validation.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const UPSELL_PLAN_TRIGGERS = [
  "onboarding_completed",
  "device_added",
  "booking_created",
  "usage_threshold",
  "manual_review",
] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("commerce");
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

export function parseCreatePlanBody(body: unknown): CreateProductPlanRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateProductPlanRequest = {
    name: requireStringField(r, "name"),
    tier: requireEnum(r.tier, "tier", SUBSCRIPTION_TIERS),
  };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdatePlanBody(body: unknown): UpdateProductPlanRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateProductPlanRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.tier !== undefined) result.tier = requireEnum(r.tier, "tier", SUBSCRIPTION_TIERS);
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreatePlanPricingBody(body: unknown): CreatePlanPricingRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreatePlanPricingRequest = {
    plan_id: requireUuidField(r, "plan_id"),
  };
  if (r.currency !== undefined) {
    const currency = String(r.currency).trim().toUpperCase();
    if (currency.length !== 3) {
      throw new ValidationError("currency must be a 3-letter ISO code");
    }
    result.currency = currency;
  }
  if (r.monthly_price !== undefined) result.monthly_price = r.monthly_price as number;
  if (r.yearly_price !== undefined) result.yearly_price = r.yearly_price as number;
  if (r.effective_from !== undefined) result.effective_from = String(r.effective_from);
  if (result.monthly_price === undefined && result.yearly_price === undefined) {
    throw new ValidationError("monthly_price or yearly_price is required");
  }
  return result;
}

export function parseUpdatePlanPricingBody(body: unknown): UpdatePlanPricingRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePlanPricingRequest = { id: requireUuidField(r, "id") };
  if (r.currency !== undefined) result.currency = String(r.currency);
  if (r.monthly_price !== undefined) result.monthly_price = r.monthly_price as number | null;
  if (r.yearly_price !== undefined) result.yearly_price = r.yearly_price as number | null;
  if (r.effective_from !== undefined) result.effective_from = String(r.effective_from);
  return result;
}

export function parseCreateEntitlementBody(body: unknown): CreateFeatureEntitlementRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateFeatureEntitlementRequest = {
    plan_id: requireUuidField(r, "plan_id"),
    feature_key: requireStringField(r, "feature_key"),
  };
  if (r.enabled !== undefined) result.enabled = r.enabled as boolean;
  return result;
}

export function parseUpdateEntitlementBody(body: unknown): UpdateFeatureEntitlementRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateFeatureEntitlementRequest = { id: requireUuidField(r, "id") };
  if (r.feature_key !== undefined) result.feature_key = String(r.feature_key);
  if (r.enabled !== undefined) result.enabled = r.enabled as boolean;
  return result;
}

export function parseCreateUpsellRuleBody(body: unknown): CreateUpsellRuleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateUpsellRuleRequest = {};
  if (r.trigger_event !== undefined) {
    result.trigger_event = requireEnum(r.trigger_event, "trigger_event", UPSELL_PLAN_TRIGGERS);
  }
  if (r.recommended_plan_id !== undefined) {
    result.recommended_plan_id = requireUuidField(r, "recommended_plan_id");
  }
  if (r.rule_config !== undefined) result.rule_config = requireJsonObject(r.rule_config, "rule_config");
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateUpsellRuleBody(body: unknown): UpdateUpsellRuleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateUpsellRuleRequest = { id: requireUuidField(r, "id") };
  if (r.trigger_event !== undefined) {
    result.trigger_event =
      r.trigger_event === null
        ? null
        : requireEnum(r.trigger_event, "trigger_event", UPSELL_PLAN_TRIGGERS);
  }
  if (r.recommended_plan_id !== undefined) {
    result.recommended_plan_id =
      r.recommended_plan_id === null ? null : requireUuidField(r, "recommended_plan_id");
  }
  if (r.rule_config !== undefined) {
    result.rule_config =
      r.rule_config === null ? null : requireJsonObject(r.rule_config, "rule_config");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseChangePlanBody(body: unknown): ChangePlanRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return { plan_id: requireUuidField(body as Record<string, unknown>, "plan_id") };
}
