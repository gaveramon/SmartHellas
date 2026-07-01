import { ValidationError } from "../shared/errors.ts";
import type {
  ConnectIntegrationRequest,
  CreateDeviceMapRequest,
  CreateWebhookDefinitionRequest,
  DisconnectIntegrationRequest,
  OAuthStartRequest,
  SyncIntegrationRequest,
  UpdateDeviceMapRequest,
  UpdateIntegrationRequest,
  UpdateWebhookDefinitionRequest,
} from "./types.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("integrations");
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

export function parseCodeQuery(req: Request, param = "code"): string {
  const value = new URL(req.url).searchParams.get(param);
  if (!value || !value.trim()) {
    throw new ValidationError(`${param} query parameter is required`, { field: param });
  }
  return value.trim();
}

export function optionalUuidQuery(req: Request, param: string): string | undefined {
  const value = new URL(req.url).searchParams.get(param);
  if (!value) return undefined;
  if (!isUuid(value)) {
    throw new ValidationError(`${param} must be a valid UUID`, { field: param });
  }
  return value;
}

export function optionalCodeQuery(req: Request, param: string): string | undefined {
  const value = new URL(req.url).searchParams.get(param);
  if (!value) return undefined;
  return value.trim();
}

function requireUuidField(record: Record<string, unknown>, field: string): string {
  const value = record[field];
  if (typeof value !== "string" || !isUuid(value)) {
    throw new ValidationError(`${field} must be a valid UUID`, { field });
  }
  return value;
}

function requireProviderCode(record: Record<string, unknown>, field = "provider_code"): string {
  const value = record[field];
  if (typeof value !== "string" || !value.trim()) {
    throw new ValidationError(`${field} is required`, { field });
  }
  return value.trim().toLowerCase();
}

export function parseConnectBody(body: unknown): ConnectIntegrationRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: ConnectIntegrationRequest = {
    provider_code: requireProviderCode(r),
  };
  if (r.credentials_ref !== undefined && r.credentials_ref !== null) {
    if (typeof r.credentials_ref !== "string" || !r.credentials_ref.trim()) {
      throw new ValidationError("credentials_ref must be a non-empty string");
    }
    result.credentials_ref = r.credentials_ref.trim();
  }
  if (r.config !== undefined) {
    if (typeof r.config !== "object" || Array.isArray(r.config)) {
      throw new ValidationError("config must be an object");
    }
    result.config = r.config as Record<string, unknown>;
  }
  if (r.is_enabled !== undefined) {
    if (typeof r.is_enabled !== "boolean") {
      throw new ValidationError("is_enabled must be a boolean");
    }
    result.is_enabled = r.is_enabled;
  }
  return result;
}

export function parseUpdateIntegrationBody(body: unknown): UpdateIntegrationRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateIntegrationRequest = {
    provider_code: requireProviderCode(r),
  };
  if (r.credentials_ref !== undefined) {
    result.credentials_ref =
      r.credentials_ref === null ? null : String(r.credentials_ref).trim();
  }
  if (r.config !== undefined) {
    if (typeof r.config !== "object" || Array.isArray(r.config)) {
      throw new ValidationError("config must be an object");
    }
    result.config = r.config as Record<string, unknown>;
  }
  if (r.is_enabled !== undefined) {
    result.is_enabled = r.is_enabled as boolean;
  }
  return result;
}

export function parseDisconnectBody(body: unknown): DisconnectIntegrationRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return { provider_code: requireProviderCode(body as Record<string, unknown>) };
}

export function parseCreateWebhookBody(body: unknown): CreateWebhookDefinitionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const eventType = r.event_type;
  const targetUrl = r.target_url;
  if (typeof eventType !== "string" || !eventType.trim()) {
    throw new ValidationError("event_type is required");
  }
  if (typeof targetUrl !== "string" || !targetUrl.trim()) {
    throw new ValidationError("target_url is required");
  }
  try {
    new URL(targetUrl);
  } catch {
    throw new ValidationError("target_url must be a valid URL");
  }
  const result: CreateWebhookDefinitionRequest = {
    provider_code: requireProviderCode(r),
    event_type: eventType.trim(),
    target_url: targetUrl.trim(),
  };
  if (r.signing_secret_ref !== undefined && r.signing_secret_ref !== null) {
    result.signing_secret_ref = String(r.signing_secret_ref).trim();
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateWebhookBody(body: unknown): UpdateWebhookDefinitionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateWebhookDefinitionRequest = { id: requireUuidField(r, "id") };
  if (r.event_type !== undefined) result.event_type = String(r.event_type);
  if (r.target_url !== undefined) {
    try {
      new URL(String(r.target_url));
    } catch {
      throw new ValidationError("target_url must be a valid URL");
    }
    result.target_url = String(r.target_url);
  }
  if (r.signing_secret_ref !== undefined) {
    result.signing_secret_ref = r.signing_secret_ref as string | null;
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateDeviceMapBody(body: unknown): CreateDeviceMapRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const externalId = r.external_id;
  if (typeof externalId !== "string" || !externalId.trim()) {
    throw new ValidationError("external_id is required");
  }
  const result: CreateDeviceMapRequest = {
    device_id: requireUuidField(r, "device_id"),
    provider_code: requireProviderCode(r),
    external_id: externalId.trim(),
  };
  if (r.config !== undefined) {
    result.config = r.config as Record<string, unknown>;
  }
  return result;
}

export function parseUpdateDeviceMapBody(body: unknown): UpdateDeviceMapRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateDeviceMapRequest = { id: requireUuidField(r, "id") };
  if (r.external_id !== undefined) {
    if (typeof r.external_id !== "string" || !r.external_id.trim()) {
      throw new ValidationError("external_id must be a non-empty string");
    }
    result.external_id = r.external_id.trim();
  }
  if (r.config !== undefined) {
    result.config = r.config as Record<string, unknown>;
  }
  return result;
}

export function parseOAuthStartBody(body: unknown): OAuthStartRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: OAuthStartRequest = { provider_code: requireProviderCode(r) };
  if (r.redirect_uri !== undefined) {
    result.redirect_uri = String(r.redirect_uri);
  }
  return result;
}

export function parseOAuthCallbackQuery(req: Request): {
  code: string;
  state: string;
  error?: string;
} {
  const url = new URL(req.url);
  const error = url.searchParams.get("error");
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  if (error) {
    return { code: "", state: state ?? "", error };
  }
  if (!code || !state) {
    throw new ValidationError("OAuth callback requires code and state query parameters");
  }
  return { code, state };
}

export function parseSyncBody(body: unknown): SyncIntegrationRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: SyncIntegrationRequest = { provider_code: requireProviderCode(r) };
  if (r.scope !== undefined) {
    if (typeof r.scope !== "object" || Array.isArray(r.scope)) {
      throw new ValidationError("scope must be an object");
    }
    result.scope = r.scope as Record<string, unknown>;
  }
  return result;
}

export function parseDeleteIdBody(body: unknown): string {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return requireUuidField(body as Record<string, unknown>, "id");
}
