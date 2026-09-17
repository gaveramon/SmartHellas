import { ValidationError } from "../shared/errors.ts";
import {
  optionalEnum,
  optionalEnumQuery,
  requireEnum,
} from "../shared/validation.ts";
import type {
  CreateBlueprintRequest,
  CreateBlueprintStepRequest,
  CreateBundleDeviceRequest,
  CreateDeviceBundleRequest,
  CreatePreconfigDeviceMapRequest,
  CreatePreconfigTemplateRequest,
  UpdateBlueprintRequest,
  UpdateBlueprintStepRequest,
  UpdateBundleDeviceRequest,
  UpdateDeviceBundleRequest,
  UpdatePreconfigDeviceMapRequest,
  UpdatePreconfigTemplateRequest,
} from "./types.ts";

export { optionalEnumQuery } from "../shared/validation.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const PROPERTY_TYPES = [
  "apartment",
  "house",
  "villa",
  "hotel",
  "guesthouse",
  "studio",
  "hostel",
  "resort",
  "other",
] as const;

export const ROOM_TYPES = [
  "living_room",
  "bedroom",
  "bathroom",
  "kitchen",
  "hallway",
  "outdoor",
  "office",
  "storage",
  "laundry",
  "garage",
  "toilet",
  "other",
] as const;

export const DEVICE_PROTOCOLS = [
  "zigbee",
  "wifi",
  "bluetooth",
  "infrared",
  "matter",
  "thread",
  "z_wave",
  "ble",
  "ethernet",
] as const;

export const ONBOARDING_STEP_TYPES = [
  "wifi_setup",
  "device_assignment",
  "room_mapping",
  "integration_link",
  "testing",
  "finalization",
] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("preconfig");
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

export function parseCodeQuery(req: Request, param = "code"): string {
  const value = new URL(req.url).searchParams.get(param);
  if (!value || !value.trim()) {
    throw new ValidationError(`${param} query parameter is required`, { field: param });
  }
  return value.trim();
}

export function optionalCodeQuery(req: Request, param: string): string | undefined {
  const value = new URL(req.url).searchParams.get(param);
  if (!value) return undefined;
  return value.trim();
}

export function parseActiveOnlyQuery(req: Request): boolean {
  const value = new URL(req.url).searchParams.get("active_only");
  if (value === null || value === "true" || value === "1") return true;
  if (value === "false" || value === "0") return false;
  throw new ValidationError("active_only must be true or false");
}

export function parseBundleVersionQuery(req: Request): number | undefined {
  const value = new URL(req.url).searchParams.get("version");
  if (!value) return undefined;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new ValidationError("version must be a positive integer");
  }
  return parsed;
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

export function parseCreateBundleBody(body: unknown): CreateDeviceBundleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateDeviceBundleRequest = {
    code: requireStringField(r, "code"),
    name: requireStringField(r, "name"),
  };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.property_type !== undefined) {
    result.property_type = requireEnum(r.property_type, "property_type", PROPERTY_TYPES);
  }
  if (r.version !== undefined) result.version = r.version as number;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  if (r.is_system !== undefined) result.is_system = r.is_system as boolean;
  return result;
}

export function parseUpdateBundleBody(body: unknown): UpdateDeviceBundleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateDeviceBundleRequest = { id: requireUuidField(r, "id") };
  if (r.code !== undefined) result.code = String(r.code);
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.property_type !== undefined) {
    result.property_type =
      r.property_type === null
        ? null
        : requireEnum(r.property_type, "property_type", PROPERTY_TYPES);
  }
  if (r.version !== undefined) result.version = r.version as number;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  if (r.is_system !== undefined) result.is_system = r.is_system as boolean;
  return result;
}

export function parseCreateBundleDeviceBody(body: unknown): CreateBundleDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateBundleDeviceRequest = {
    bundle_id: requireUuidField(r, "bundle_id"),
    category_code: requireStringField(r, "category_code"),
  };
  if (r.quantity !== undefined) {
    if (typeof r.quantity !== "number" || r.quantity <= 0) {
      throw new ValidationError("quantity must be a positive integer");
    }
    result.quantity = r.quantity;
  }
  if (r.is_required !== undefined) result.is_required = r.is_required as boolean;
  if (r.config_hint !== undefined) result.config_hint = requireJsonObject(r.config_hint, "config_hint");
  return result;
}

export function parseUpdateBundleDeviceBody(body: unknown): UpdateBundleDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateBundleDeviceRequest = { id: requireUuidField(r, "id") };
  if (r.quantity !== undefined) result.quantity = r.quantity as number;
  if (r.is_required !== undefined) result.is_required = r.is_required as boolean;
  if (r.config_hint !== undefined) result.config_hint = requireJsonObject(r.config_hint, "config_hint");
  return result;
}

export function parseCreateBlueprintBody(body: unknown): CreateBlueprintRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateBlueprintRequest = {
    code: requireStringField(r, "code"),
    name: requireStringField(r, "name"),
  };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.property_type !== undefined) {
    result.property_type = requireEnum(r.property_type, "property_type", PROPERTY_TYPES);
  }
  if (r.is_system !== undefined) result.is_system = r.is_system as boolean;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateBlueprintBody(body: unknown): UpdateBlueprintRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateBlueprintRequest = { id: requireUuidField(r, "id") };
  if (r.code !== undefined) result.code = String(r.code);
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.property_type !== undefined) {
    result.property_type =
      r.property_type === null
        ? null
        : requireEnum(r.property_type, "property_type", PROPERTY_TYPES);
  }
  if (r.is_system !== undefined) result.is_system = r.is_system as boolean;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateBlueprintStepBody(body: unknown): CreateBlueprintStepRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const stepOrder = r.step_order;
  if (typeof stepOrder !== "number" || stepOrder <= 0) {
    throw new ValidationError("step_order must be a positive integer");
  }
  return {
    blueprint_id: requireUuidField(r, "blueprint_id"),
    step_order: stepOrder,
    step_type: requireEnum(r.step_type, "step_type", ONBOARDING_STEP_TYPES),
    config: r.config !== undefined ? requireJsonObject(r.config, "config") : undefined,
  };
}

export function parseUpdateBlueprintStepBody(body: unknown): UpdateBlueprintStepRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateBlueprintStepRequest = { id: requireUuidField(r, "id") };
  if (r.step_order !== undefined) result.step_order = r.step_order as number;
  if (r.step_type !== undefined) {
    result.step_type = requireEnum(r.step_type, "step_type", ONBOARDING_STEP_TYPES);
  }
  if (r.config !== undefined) result.config = requireJsonObject(r.config, "config");
  return result;
}

export function parseCreateTemplateBody(body: unknown): CreatePreconfigTemplateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreatePreconfigTemplateRequest = {
    device_bundle_id: requireUuidField(r, "device_bundle_id"),
    name: requireStringField(r, "name"),
  };
  if (r.onboarding_blueprint_id !== undefined) {
    result.onboarding_blueprint_id = requireUuidField(r, "onboarding_blueprint_id");
  }
  if (r.description !== undefined) result.description = String(r.description);
  if (r.property_type !== undefined) {
    result.property_type = requireEnum(r.property_type, "property_type", PROPERTY_TYPES);
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  if (r.version !== undefined) result.version = r.version as number;
  return result;
}

export function parseUpdateTemplateBody(body: unknown): UpdatePreconfigTemplateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePreconfigTemplateRequest = { id: requireUuidField(r, "id") };
  if (r.device_bundle_id !== undefined) {
    result.device_bundle_id = requireUuidField(r, "device_bundle_id");
  }
  if (r.onboarding_blueprint_id !== undefined) {
    result.onboarding_blueprint_id =
      r.onboarding_blueprint_id === null
        ? null
        : requireUuidField(r, "onboarding_blueprint_id");
  }
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.property_type !== undefined) {
    result.property_type =
      r.property_type === null
        ? null
        : requireEnum(r.property_type, "property_type", PROPERTY_TYPES);
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  if (r.version !== undefined) result.version = r.version as number;
  return result;
}

export function parseCreateDeviceMapBody(body: unknown): CreatePreconfigDeviceMapRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreatePreconfigDeviceMapRequest = {
    template_id: requireUuidField(r, "template_id"),
    category_code: requireStringField(r, "category_code"),
    room_type: requireEnum(r.room_type, "room_type", ROOM_TYPES),
  };
  if (r.recommended_protocol !== undefined) {
    result.recommended_protocol = requireEnum(
      r.recommended_protocol,
      "recommended_protocol",
      DEVICE_PROTOCOLS,
    );
  }
  if (r.default_config !== undefined) {
    result.default_config = requireJsonObject(r.default_config, "default_config");
  }
  return result;
}

export function parseUpdateDeviceMapBody(body: unknown): UpdatePreconfigDeviceMapRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePreconfigDeviceMapRequest = { id: requireUuidField(r, "id") };
  if (r.category_code !== undefined) result.category_code = String(r.category_code);
  if (r.room_type !== undefined) {
    result.room_type = requireEnum(r.room_type, "room_type", ROOM_TYPES);
  }
  if (r.recommended_protocol !== undefined) {
    result.recommended_protocol =
      r.recommended_protocol === null
        ? null
        : requireEnum(r.recommended_protocol, "recommended_protocol", DEVICE_PROTOCOLS);
  }
  if (r.default_config !== undefined) {
    result.default_config = requireJsonObject(r.default_config, "default_config");
  }
  return result;
}
