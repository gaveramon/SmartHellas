import { ValidationError } from "../shared/errors.ts";
import { optionalEnum, requireEnum } from "../shared/validation.ts";
import type {
  AssignDeviceRequest,
  CreateDeviceRequest,
  CreatePropertyRequest,
  CreateRoomRequest,
  DeleteDeviceRequest,
  DeletePropertyRequest,
  DeleteRoomRequest,
  UnassignDeviceRequest,
  UpdateDeviceRequest,
  UpdatePropertyRequest,
  UpdateRoomRequest,
  UpsertDeviceConfigRequest,
} from "./types.ts";

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

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("devices");
  if (idx >= 0 && segments.length > idx + 1) {
    return segments[idx + 1];
  }
  return segments[segments.length - 1] ?? "";
}

export function parseUuidQuery(req: Request, param = "id"): string {
  const value = new URL(req.url).searchParams.get(param);
  if (!value || !isUuid(value)) {
    throw new ValidationError(`${param} query parameter must be a valid UUID`, {
      field: param,
    });
  }
  return value;
}

export function optionalUuidQuery(
  req: Request,
  param: string,
): string | undefined {
  const value = new URL(req.url).searchParams.get(param);
  if (!value) return undefined;
  if (!isUuid(value)) {
    throw new ValidationError(`${param} must be a valid UUID`, { field: param });
  }
  return value;
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

export function parseCreatePropertyBody(body: unknown): CreatePropertyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const name = r.name;
  if (typeof name !== "string" || !name.trim()) {
    throw new ValidationError("name is required", { field: "name" });
  }
  const propertyType = requireEnum(r.property_type, "property_type", PROPERTY_TYPES);
  const result: CreatePropertyRequest = {
    name: name.trim(),
    property_type: propertyType,
  };
  if (r.address !== undefined && r.address !== null) {
    if (typeof r.address !== "string") {
      throw new ValidationError("address must be a string");
    }
    result.address = r.address;
  }
  if (r.timezone !== undefined && typeof r.timezone === "string") {
    result.timezone = r.timezone;
  }
  return result;
}

export function parseUpdatePropertyBody(body: unknown): UpdatePropertyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePropertyRequest = { id: requireUuidField(r, "id") };

  if (r.name !== undefined) {
    if (typeof r.name !== "string" || !r.name.trim()) {
      throw new ValidationError("name must be a non-empty string");
    }
    result.name = r.name.trim();
  }
  if (r.address !== undefined) {
    result.address = r.address === null ? null : String(r.address);
  }
  const propertyType = optionalEnum(r.property_type, "property_type", PROPERTY_TYPES);
  if (propertyType) result.property_type = propertyType;
  if (r.timezone !== undefined && typeof r.timezone === "string") {
    result.timezone = r.timezone;
  }

  if (
    !result.name &&
    result.address === undefined &&
    !result.property_type &&
    !result.timezone
  ) {
    throw new ValidationError("At least one property field is required");
  }
  return result;
}

export function parseDeletePropertyBody(body: unknown): DeletePropertyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return { id: requireUuidField(body as Record<string, unknown>, "id") };
}

export function parseCreateRoomBody(body: unknown): CreateRoomRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const name = r.name;
  if (typeof name !== "string" || !name.trim()) {
    throw new ValidationError("name is required");
  }
  const roomType = requireEnum(r.room_type, "room_type", ROOM_TYPES);
  const result: CreateRoomRequest = {
    property_id: requireUuidField(r, "property_id"),
    name: name.trim(),
    room_type: roomType,
  };
  if (r.floor !== undefined && r.floor !== null) {
    if (typeof r.floor !== "number" || !Number.isInteger(r.floor)) {
      throw new ValidationError("floor must be an integer");
    }
    result.floor = r.floor;
  }
  return result;
}

export function parseUpdateRoomBody(body: unknown): UpdateRoomRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateRoomRequest = { id: requireUuidField(r, "id") };

  if (r.name !== undefined) {
    if (typeof r.name !== "string" || !r.name.trim()) {
      throw new ValidationError("name must be a non-empty string");
    }
    result.name = r.name.trim();
  }
  const roomType = optionalEnum(r.room_type, "room_type", ROOM_TYPES);
  if (roomType) result.room_type = roomType;
  if (r.floor !== undefined) {
    if (r.floor !== null && (typeof r.floor !== "number" || !Number.isInteger(r.floor))) {
      throw new ValidationError("floor must be an integer or null");
    }
    result.floor = r.floor as number | null;
  }

  if (!result.name && !result.room_type && result.floor === undefined) {
    throw new ValidationError("At least one room field is required");
  }
  return result;
}

export function parseDeleteRoomBody(body: unknown): DeleteRoomRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return { id: requireUuidField(body as Record<string, unknown>, "id") };
}

export function parseCreateDeviceBody(body: unknown): CreateDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const deviceName = r.device_name;
  if (typeof deviceName !== "string" || !deviceName.trim()) {
    throw new ValidationError("device_name is required");
  }
  const categoryCode = r.category_code;
  if (typeof categoryCode !== "string" || !categoryCode.trim()) {
    throw new ValidationError("category_code is required");
  }
  const protocol = requireEnum(r.protocol, "protocol", DEVICE_PROTOCOLS);

  const result: CreateDeviceRequest = {
    device_name: deviceName.trim(),
    category_code: categoryCode.trim(),
    protocol,
  };

  if (r.parent_device_id !== undefined && r.parent_device_id !== null) {
    result.parent_device_id = requireUuidField(
      { parent_device_id: r.parent_device_id },
      "parent_device_id",
    );
  }
  if (r.model !== undefined && r.model !== null) {
    result.model = String(r.model);
  }
  if (r.manufacturer !== undefined && r.manufacturer !== null) {
    result.manufacturer = String(r.manufacturer);
  }
  if (r.is_active !== undefined) {
    if (typeof r.is_active !== "boolean") {
      throw new ValidationError("is_active must be a boolean");
    }
    result.is_active = r.is_active;
  }
  return result;
}

export function parseUpdateDeviceBody(body: unknown): UpdateDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateDeviceRequest = { id: requireUuidField(r, "id") };

  if (r.device_name !== undefined) {
    if (typeof r.device_name !== "string" || !r.device_name.trim()) {
      throw new ValidationError("device_name must be a non-empty string");
    }
    result.device_name = r.device_name.trim();
  }
  if (r.category_code !== undefined) {
    if (typeof r.category_code !== "string" || !r.category_code.trim()) {
      throw new ValidationError("category_code must be a non-empty string");
    }
    result.category_code = r.category_code.trim();
  }
  const protocol = optionalEnum(r.protocol, "protocol", DEVICE_PROTOCOLS);
  if (protocol) result.protocol = protocol;
  if (r.parent_device_id !== undefined) {
    result.parent_device_id =
      r.parent_device_id === null
        ? null
        : requireUuidField({ parent_device_id: r.parent_device_id }, "parent_device_id");
  }
  if (r.model !== undefined) result.model = r.model === null ? null : String(r.model);
  if (r.manufacturer !== undefined) {
    result.manufacturer = r.manufacturer === null ? null : String(r.manufacturer);
  }
  if (r.is_active !== undefined) {
    if (typeof r.is_active !== "boolean") {
      throw new ValidationError("is_active must be a boolean");
    }
    result.is_active = r.is_active;
  }

  const hasUpdate =
    result.device_name ||
    result.category_code ||
    result.protocol ||
    result.parent_device_id !== undefined ||
    result.model !== undefined ||
    result.manufacturer !== undefined ||
    result.is_active !== undefined;

  if (!hasUpdate) {
    throw new ValidationError("At least one device field is required");
  }
  return result;
}

export function parseDeleteDeviceBody(body: unknown): DeleteDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return { id: requireUuidField(body as Record<string, unknown>, "id") };
}

export function parseAssignDeviceBody(body: unknown): AssignDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  return {
    device_id: requireUuidField(r, "device_id"),
    room_id: requireUuidField(r, "room_id"),
  };
}

export function parseUnassignDeviceBody(body: unknown): UnassignDeviceRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return { device_id: requireUuidField(body as Record<string, unknown>, "device_id") };
}

export function parseUpsertDeviceConfigBody(
  body: unknown,
): UpsertDeviceConfigRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const config = r.config;
  if (!config || typeof config !== "object" || Array.isArray(config)) {
    throw new ValidationError("config must be a JSON object");
  }
  return {
    device_id: requireUuidField(r, "device_id"),
    config: config as Record<string, unknown>,
  };
}

export function parseDeviceConfigQuery(req: Request): string {
  return parseUuidQuery(req, "device_id");
}
