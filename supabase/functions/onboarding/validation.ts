import { ValidationError } from "../shared/errors.ts";
import { optionalEnum } from "../shared/validation.ts";
import type {
  CreateDeviceMappingRequest,
  CreateOnboardingNoteRequest,
  CreateOnboardingSessionRequest,
  CreateRoomMappingRequest,
  UpdateChecklistItemRequest,
  UpdateDeviceMappingRequest,
  UpdateOnboardingSessionRequest,
  UpdateRoomMappingRequest,
  UpdateStepStateRequest,
  UpsertChecklistItemRequest,
  LifecycleTransitionRequest,
} from "./types.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const ONBOARDING_STATUSES = [
  "not_started",
  "in_progress",
  "waiting_user",
  "completed",
  "blocked",
] as const;

export const ONBOARDING_STEP_TYPES = [
  "wifi_setup",
  "device_assignment",
  "room_mapping",
  "integration_link",
  "testing",
  "finalization",
] as const;

export const ONBOARDING_STEP_STATUSES = [
  "pending",
  "in_progress",
  "completed",
  "skipped",
  "blocked",
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

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("onboarding");
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

export function parseDeleteIdBody(body: unknown): string {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return requireUuidField(body as Record<string, unknown>, "id");
}

export function parseCreateSessionBody(body: unknown): CreateOnboardingSessionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateOnboardingSessionRequest = {
    property_id: requireUuidField(r, "property_id"),
  };
  if (r.preconfig_template_id !== undefined) {
    result.preconfig_template_id = requireUuidField(r, "preconfig_template_id");
  }
  if (r.onboarding_blueprint_id !== undefined) {
    result.onboarding_blueprint_id = requireUuidField(r, "onboarding_blueprint_id");
  }
  if (r.status !== undefined) {
    result.status = optionalEnum(r.status, "status", ONBOARDING_STATUSES);
  }
  if (r.current_step !== undefined) {
    result.current_step = optionalEnum(r.current_step, "current_step", ONBOARDING_STEP_TYPES);
  }
  return result;
}

export function parseUpdateSessionBody(body: unknown): UpdateOnboardingSessionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateOnboardingSessionRequest = { id: requireUuidField(r, "id") };
  if (r.preconfig_template_id !== undefined) {
    result.preconfig_template_id =
      r.preconfig_template_id === null ? null : requireUuidField(r, "preconfig_template_id");
  }
  if (r.onboarding_blueprint_id !== undefined) {
    result.onboarding_blueprint_id =
      r.onboarding_blueprint_id === null ? null : requireUuidField(r, "onboarding_blueprint_id");
  }
  if (r.status !== undefined) {
    result.status = optionalEnum(r.status, "status", ONBOARDING_STATUSES);
  }
  if (r.current_step !== undefined) {
    result.current_step =
      r.current_step === null
        ? null
        : optionalEnum(r.current_step, "current_step", ONBOARDING_STEP_TYPES);
  }
  return result;
}

export function parseUpdateStepStateBody(body: unknown): UpdateStepStateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateStepStateRequest = { id: requireUuidField(r, "id") };
  if (r.status !== undefined) {
    result.status = optionalEnum(r.status, "status", ONBOARDING_STEP_STATUSES);
  }
  if (r.completed_at !== undefined) {
    result.completed_at = r.completed_at as string | null;
  }
  return result;
}

export function parseCreateRoomMappingBody(body: unknown): CreateRoomMappingRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateRoomMappingRequest = {
    session_id: requireUuidField(r, "session_id"),
    room_name: requireStringField(r, "room_name"),
  };
  if (r.room_type !== undefined) {
    result.room_type = optionalEnum(r.room_type, "room_type", ROOM_TYPES);
  }
  return result;
}

export function parseUpdateRoomMappingBody(body: unknown): UpdateRoomMappingRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateRoomMappingRequest = { id: requireUuidField(r, "id") };
  if (r.room_name !== undefined) result.room_name = String(r.room_name);
  if (r.room_type !== undefined) {
    result.room_type =
      r.room_type === null ? null : optionalEnum(r.room_type, "room_type", ROOM_TYPES);
  }
  if (r.promoted_room_id !== undefined) {
    result.promoted_room_id =
      r.promoted_room_id === null ? null : requireUuidField(r, "promoted_room_id");
  }
  return result;
}

export function parseCreateDeviceMappingBody(body: unknown): CreateDeviceMappingRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateDeviceMappingRequest = {
    session_id: requireUuidField(r, "session_id"),
  };
  if (r.category_code !== undefined) result.category_code = String(r.category_code);
  if (r.room_name !== undefined) result.room_name = String(r.room_name);
  if (r.desired_action !== undefined) result.desired_action = String(r.desired_action);
  if (r.scan_status !== undefined) {
    result.scan_status = optionalEnum(r.scan_status, "scan_status", ONBOARDING_STEP_STATUSES);
  }
  return result;
}

export function parseUpdateDeviceMappingBody(body: unknown): UpdateDeviceMappingRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateDeviceMappingRequest = { id: requireUuidField(r, "id") };
  if (r.category_code !== undefined) result.category_code = r.category_code as string | null;
  if (r.room_name !== undefined) result.room_name = r.room_name as string | null;
  if (r.desired_action !== undefined) result.desired_action = r.desired_action as string | null;
  if (r.device_id !== undefined) {
    result.device_id = r.device_id === null ? null : requireUuidField(r, "device_id");
  }
  if (r.scan_status !== undefined) {
    result.scan_status = optionalEnum(r.scan_status, "scan_status", ONBOARDING_STEP_STATUSES);
  }
  if (r.scanned_at !== undefined) result.scanned_at = r.scanned_at as string | null;
  return result;
}

export function parseUpsertChecklistBody(body: unknown): UpsertChecklistItemRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpsertChecklistItemRequest = {
    session_id: requireUuidField(r, "session_id"),
    checklist_key: requireStringField(r, "checklist_key"),
  };
  if (r.is_completed !== undefined) result.is_completed = r.is_completed as boolean;
  return result;
}

export function parseUpdateChecklistBody(body: unknown): UpdateChecklistItemRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateChecklistItemRequest = { id: requireUuidField(r, "id") };
  if (r.is_completed !== undefined) result.is_completed = r.is_completed as boolean;
  return result;
}

export function parseCreateNoteBody(body: unknown): CreateOnboardingNoteRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  return {
    session_id: requireUuidField(r, "session_id"),
    note: requireStringField(r, "note"),
  };
}

export const ONBOARDING_LIFECYCLE_STATES = [
  "created",
  "pre_onboarding",
  "configured",
  "devices_assigned",
  "shipped",
  "installed",
  "verified",
  "active",
] as const;

export function parseLifecycleTransitionBody(
  body: unknown,
): LifecycleTransitionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const toState = optionalEnum(r.to_state, "to_state", ONBOARDING_LIFECYCLE_STATES);
  if (!toState) {
    throw new ValidationError("to_state is required");
  }
  const result: LifecycleTransitionRequest = {
    property_id: requireUuidField(r, "property_id"),
    to_state: toState,
  };
  if (r.metadata !== undefined) {
    if (typeof r.metadata !== "object" || Array.isArray(r.metadata)) {
      throw new ValidationError("metadata must be an object");
    }
    result.metadata = r.metadata as Record<string, unknown>;
  }
  return result;
}
