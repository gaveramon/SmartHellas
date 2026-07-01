import { ValidationError } from "../shared/errors.ts";
import type {
  CreateDashboardRequest,
  CreateFeatureFlagRequest,
  UpdateDashboardRequest,
  UpdateFeatureFlagRequest,
  UpsertPortalSettingsRequest,
  UpsertPreferenceRequest,
  UpdatePreferenceRequest,
} from "./types.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const UI_FEATURE_KEY_RE = /^ui_/;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("portal");
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

export function parsePreferenceKeyQuery(req: Request): string {
  const value = new URL(req.url).searchParams.get("preference_key");
  if (!value || !value.trim()) {
    throw new ValidationError("preference_key query parameter is required");
  }
  return value.trim();
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

function requireUiFeatureKey(value: unknown, field = "feature_key"): string {
  const key = requireStringField({ [field]: value } as Record<string, unknown>, field);
  if (!UI_FEATURE_KEY_RE.test(key)) {
    throw new ValidationError(`${field} must start with ui_`, { field });
  }
  return key;
}

export function parseDeleteIdBody(body: unknown): string {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return requireUuidField(body as Record<string, unknown>, "id");
}

export function parseUpsertSettingsBody(body: unknown): UpsertPortalSettingsRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpsertPortalSettingsRequest = {};
  if (r.theme !== undefined) {
    result.theme =
      r.theme === null ? null : requireJsonObject(r.theme, "theme");
  }
  if (r.default_language !== undefined) {
    result.default_language = String(r.default_language);
  }
  if (Object.keys(result).length === 0) {
    throw new ValidationError("At least one settings field is required");
  }
  return result;
}

export function parseCreateDashboardBody(body: unknown): CreateDashboardRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateDashboardRequest = { name: requireStringField(r, "name") };
  if (r.layout !== undefined) result.layout = requireJsonObject(r.layout, "layout");
  if (r.is_default !== undefined) result.is_default = r.is_default as boolean;
  return result;
}

export function parseUpdateDashboardBody(body: unknown): UpdateDashboardRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateDashboardRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.layout !== undefined) {
    result.layout = r.layout === null ? null : requireJsonObject(r.layout, "layout");
  }
  if (r.is_default !== undefined) result.is_default = r.is_default as boolean;
  return result;
}

export function parseUpsertPreferenceBody(body: unknown): UpsertPreferenceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  return {
    preference_key: requireStringField(r, "preference_key"),
    value: requireJsonObject(r.value, "value"),
  };
}

export function parseUpdatePreferenceBody(body: unknown): UpdatePreferenceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePreferenceRequest = {
    preference_key: requireStringField(r, "preference_key"),
  };
  if (r.value !== undefined) result.value = requireJsonObject(r.value, "value");
  return result;
}

export function parseDeletePreferenceBody(body: unknown): string {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return requireStringField(body as Record<string, unknown>, "preference_key");
}

export function parseCreateFeatureFlagBody(body: unknown): CreateFeatureFlagRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateFeatureFlagRequest = {
    feature_key: requireUiFeatureKey(r.feature_key),
  };
  if (r.enabled !== undefined) result.enabled = r.enabled as boolean;
  return result;
}

export function parseUpdateFeatureFlagBody(body: unknown): UpdateFeatureFlagRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateFeatureFlagRequest = { id: requireUuidField(r, "id") };
  if (r.feature_key !== undefined) result.feature_key = requireUiFeatureKey(r.feature_key);
  if (r.enabled !== undefined) result.enabled = r.enabled as boolean;
  return result;
}
