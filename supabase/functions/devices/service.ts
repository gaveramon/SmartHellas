import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  AssignDeviceRequest,
  CreateDeviceRequest,
  CreatePropertyRequest,
  CreateRoomRequest,
  DeviceCategoryRow,
  DeviceConfigurationRow,
  DeviceDetail,
  DeviceRow,
  PropertyRow,
  RoomRow,
  UnassignDeviceRequest,
  UpdateDeviceRequest,
  UpdatePropertyRequest,
  UpdateRoomRequest,
  UpsertDeviceConfigRequest,
} from "./types.ts";

function tid(auth: AuthContext): string {
  return requireTenant(auth);
}

export async function listProperties(auth: AuthContext): Promise<PropertyRow[]> {
  tid(auth);
  return await callModuleApiAuth<PropertyRow[]>(auth, "devices", "list_properties");
}

export async function getProperty(auth: AuthContext, propertyId: string): Promise<PropertyRow> {
  tid(auth);
  return await callModuleApiAuth<PropertyRow>(auth, "devices", "get_property", { id: propertyId });
}

export async function createProperty(
  auth: AuthContext,
  input: CreatePropertyRequest,
): Promise<PropertyRow> {
  return await callModuleApiAuth<PropertyRow>(auth, "devices", "create_property", { ...input });
}

export async function updateProperty(
  auth: AuthContext,
  input: UpdatePropertyRequest,
): Promise<PropertyRow> {
  return await callModuleApiAuth<PropertyRow>(auth, "devices", "update_property", { ...input });
}

export async function deleteProperty(
  auth: AuthContext,
  propertyId: string,
): Promise<{ deleted: true; id: string }> {
  return await callModuleApiAuth(auth, "devices", "delete_property", { id: propertyId });
}

export async function listRooms(auth: AuthContext, propertyId?: string): Promise<RoomRow[]> {
  tid(auth);
  return await callModuleApiAuth<RoomRow[]>(
    auth,
    "devices",
    "list_rooms",
    propertyId ? { property_id: propertyId } : {},
  );
}

export async function getRoom(auth: AuthContext, roomId: string): Promise<RoomRow> {
  tid(auth);
  return await callModuleApiAuth<RoomRow>(auth, "devices", "get_room", { id: roomId });
}

export async function createRoom(auth: AuthContext, input: CreateRoomRequest): Promise<RoomRow> {
  return await callModuleApiAuth<RoomRow>(auth, "devices", "create_room", { ...input });
}

export async function updateRoom(auth: AuthContext, input: UpdateRoomRequest): Promise<RoomRow> {
  return await callModuleApiAuth<RoomRow>(auth, "devices", "update_room", { ...input });
}

export async function deleteRoom(
  auth: AuthContext,
  roomId: string,
): Promise<{ deleted: true; id: string }> {
  return await callModuleApiAuth(auth, "devices", "delete_room", { id: roomId });
}

export async function listDeviceCategories(auth: AuthContext): Promise<DeviceCategoryRow[]> {
  tid(auth);
  return await callModuleApiAuth<DeviceCategoryRow[]>(auth, "devices", "list_device_categories");
}

export async function listDevices(
  auth: AuthContext,
  propertyId?: string,
  roomId?: string,
): Promise<DeviceRow[]> {
  tid(auth);
  const payload: Record<string, string> = {};
  if (propertyId) payload.property_id = propertyId;
  if (roomId) payload.room_id = roomId;
  return await callModuleApiAuth<DeviceRow[]>(auth, "devices", "list_devices", payload);
}

export async function getDevice(auth: AuthContext, deviceId: string): Promise<DeviceDetail> {
  tid(auth);
  return await callModuleApiAuth<DeviceDetail>(auth, "devices", "get_device", { id: deviceId });
}

export async function createDevice(
  auth: AuthContext,
  input: CreateDeviceRequest,
): Promise<DeviceRow> {
  return await callModuleApiAuth<DeviceRow>(auth, "devices", "create_device", { ...input });
}

export async function updateDevice(
  auth: AuthContext,
  input: UpdateDeviceRequest,
): Promise<DeviceRow> {
  return await callModuleApiAuth<DeviceRow>(auth, "devices", "update_device", { ...input });
}

export async function deleteDevice(
  auth: AuthContext,
  deviceId: string,
): Promise<{ deleted: true; id: string }> {
  return await callModuleApiAuth(auth, "devices", "delete_device", { id: deviceId });
}

export async function assignDevice(
  auth: AuthContext,
  input: AssignDeviceRequest,
): Promise<{ device_id: string; room_id: string; assigned_at: string }> {
  return await callModuleApiAuth(auth, "devices", "assign_device", { ...input });
}

export async function unassignDevice(
  auth: AuthContext,
  input: UnassignDeviceRequest,
): Promise<{ unassigned: true; device_id: string }> {
  return await callModuleApiAuth(auth, "devices", "unassign_device", { ...input });
}

export async function getDeviceConfig(
  auth: AuthContext,
  deviceId: string,
): Promise<DeviceConfigurationRow | null> {
  tid(auth);
  const result = await callModuleApiAuth<DeviceConfigurationRow | null>(
    auth,
    "devices",
    "get_device_config",
    { device_id: deviceId },
  );
  return result;
}

export async function upsertDeviceConfig(
  auth: AuthContext,
  input: UpsertDeviceConfigRequest,
): Promise<DeviceConfigurationRow> {
  return await callModuleApiAuth<DeviceConfigurationRow>(
    auth,
    "devices",
    "upsert_device_config",
    { ...input },
  );
}
