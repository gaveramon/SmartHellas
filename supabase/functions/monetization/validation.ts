import { ValidationError } from "../shared/errors.ts";
import {
  optionalEnum,
  optionalEnumQuery,
  requireEnum,
} from "../shared/validation.ts";
import type {
  CreatePackageRequest,
  CreateProposalItemRequest,
  CreateProposalRequest,
  CreateUpsellCampaignRequest,
  UpdatePackageRequest,
  UpdateProposalItemRequest,
  UpdateProposalRequest,
  UpdateUpsellCampaignRequest,
} from "./types.ts";

export { optionalEnumQuery } from "../shared/validation.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const PROPOSAL_STATUSES = [
  "draft",
  "presented",
  "accepted",
  "rejected",
  "expired",
] as const;

export const PROPOSAL_ITEM_TYPES = [
  "device_package",
  "subscription",
  "service",
] as const;

export const PACKAGE_TYPES = ["hardware", "service", "hybrid"] as const;

export const UPSELL_PACKAGE_TRIGGERS = [
  "onboarding_completed",
  "device_added",
  "booking_created",
  "usage_threshold",
  "manual_review",
] as const;

export const SERVICE_TYPES = [
  "managed_service",
  "auto_door_code",
  "energy_optimization",
  "security_monitoring",
] as const;

export const SERVICE_ACTIVATION_STATUSES = [
  "inactive",
  "pending",
  "active",
  "suspended",
  "cancelled",
  "failed",
] as const;

export const CONVERSION_EVENT_TYPES = [
  "view_proposal",
  "add_item",
  "remove_item",
  "checkout_start",
  "checkout_complete",
  "upsell_clicked",
  "proposal_accepted",
  "proposal_rejected",
] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseActiveOnlyQuery(req: Request): boolean {
  const raw = new URL(req.url).searchParams.get("active_only");
  if (raw === null) return true;
  if (raw === "true" || raw === "1") return true;
  if (raw === "false" || raw === "0") return false;
  throw new ValidationError("active_only must be true or false");
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("monetization");
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

export function parseLimitQuery(req: Request, defaultValue = 100): number {
  const raw = new URL(req.url).searchParams.get("limit");
  if (!raw) return defaultValue;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 1) {
    throw new ValidationError("limit must be a positive number");
  }
  return Math.floor(n);
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

export function parseCreateProposalBody(body: unknown): CreateProposalRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateProposalRequest = {};
  if (r.property_id !== undefined) result.property_id = requireUuidField(r, "property_id");
  if (r.total_estimated_value !== undefined) {
    result.total_estimated_value = r.total_estimated_value as number;
  }
  if (r.expires_at !== undefined) result.expires_at = String(r.expires_at);
  if (r.source_campaign_id !== undefined) {
    result.source_campaign_id = requireUuidField(r, "source_campaign_id");
  }
  return result;
}

export function parseUpdateProposalBody(body: unknown): UpdateProposalRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateProposalRequest = { id: requireUuidField(r, "id") };
  if (r.property_id !== undefined) {
    result.property_id = r.property_id === null ? null : requireUuidField(r, "property_id");
  }
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", PROPOSAL_STATUSES);
  }
  if (r.total_estimated_value !== undefined) {
    result.total_estimated_value = r.total_estimated_value as number | null;
  }
  if (r.expires_at !== undefined) {
    result.expires_at = r.expires_at === null ? null : String(r.expires_at);
  }
  if (r.source_campaign_id !== undefined) {
    result.source_campaign_id =
      r.source_campaign_id === null ? null : requireUuidField(r, "source_campaign_id");
  }
  return result;
}

export function parseCreateProposalItemBody(body: unknown): CreateProposalItemRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateProposalItemRequest = {
    proposal_id: requireUuidField(r, "proposal_id"),
    item_type: requireEnum(r.item_type, "item_type", PROPOSAL_ITEM_TYPES),
  };
  if (r.plan_id !== undefined) result.plan_id = requireUuidField(r, "plan_id");
  if (r.monetization_package_id !== undefined) {
    result.monetization_package_id = requireUuidField(r, "monetization_package_id");
  }
  if (r.reference_id !== undefined) result.reference_id = requireUuidField(r, "reference_id");
  if (r.quantity !== undefined) result.quantity = r.quantity as number;
  if (r.price_estimate !== undefined) result.price_estimate = r.price_estimate as number;
  return result;
}

export function parseUpdateProposalItemBody(body: unknown): UpdateProposalItemRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateProposalItemRequest = { id: requireUuidField(r, "id") };
  if (r.item_type !== undefined) {
    result.item_type = requireEnum(r.item_type, "item_type", PROPOSAL_ITEM_TYPES);
  }
  if (r.plan_id !== undefined) {
    result.plan_id = r.plan_id === null ? null : requireUuidField(r, "plan_id");
  }
  if (r.monetization_package_id !== undefined) {
    result.monetization_package_id =
      r.monetization_package_id === null
        ? null
        : requireUuidField(r, "monetization_package_id");
  }
  if (r.reference_id !== undefined) {
    result.reference_id =
      r.reference_id === null ? null : requireUuidField(r, "reference_id");
  }
  if (r.quantity !== undefined) result.quantity = r.quantity as number;
  if (r.price_estimate !== undefined) {
    result.price_estimate = r.price_estimate as number | null;
  }
  return result;
}

export function parseCreatePackageBody(body: unknown): CreatePackageRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreatePackageRequest = {
    name: typeof r.name === "string" ? r.name.trim() : "",
    package_type: requireEnum(r.package_type, "package_type", PACKAGE_TYPES),
  };
  if (!result.name) throw new ValidationError("name is required", { field: "name" });
  if (r.description !== undefined) result.description = String(r.description);
  if (r.device_bundle_id !== undefined) {
    result.device_bundle_id = requireUuidField(r, "device_bundle_id");
  }
  if (r.base_price !== undefined) result.base_price = r.base_price as number;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdatePackageBody(body: unknown): UpdatePackageRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePackageRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.package_type !== undefined) {
    result.package_type = requireEnum(r.package_type, "package_type", PACKAGE_TYPES);
  }
  if (r.device_bundle_id !== undefined) {
    result.device_bundle_id =
      r.device_bundle_id === null ? null : requireUuidField(r, "device_bundle_id");
  }
  if (r.base_price !== undefined) result.base_price = r.base_price as number | null;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateUpsellCampaignBody(body: unknown): CreateUpsellCampaignRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateUpsellCampaignRequest = {};
  if (r.tenant_id !== undefined) result.tenant_id = requireUuidField(r, "tenant_id");
  if (r.trigger_event !== undefined) {
    result.trigger_event = requireEnum(r.trigger_event, "trigger_event", UPSELL_PACKAGE_TRIGGERS);
  }
  if (r.target_package_id !== undefined) {
    result.target_package_id = requireUuidField(r, "target_package_id");
  }
  if (r.campaign_rules !== undefined) {
    result.campaign_rules = requireJsonObject(r.campaign_rules, "campaign_rules");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateUpsellCampaignBody(body: unknown): UpdateUpsellCampaignRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateUpsellCampaignRequest = { id: requireUuidField(r, "id") };
  if (r.trigger_event !== undefined) {
    result.trigger_event =
      r.trigger_event === null
        ? null
        : requireEnum(r.trigger_event, "trigger_event", UPSELL_PACKAGE_TRIGGERS);
  }
  if (r.target_package_id !== undefined) {
    result.target_package_id =
      r.target_package_id === null ? null : requireUuidField(r, "target_package_id");
  }
  if (r.campaign_rules !== undefined) {
    result.campaign_rules =
      r.campaign_rules === null ? null : requireJsonObject(r.campaign_rules, "campaign_rules");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}
