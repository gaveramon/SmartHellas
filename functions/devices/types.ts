export interface PropertyRow {
  id: string;
  tenant_id: string;
  name: string;
  address: string | null;
  property_type: string;
  timezone: string;
  created_at: string;
  updated_at: string;
}

export interface RoomRow {
  id: string;
  property_id: string;
  name: string;
  room_type: string;
  floor: number | null;
  created_at: string;
}

export interface DeviceCategoryRow {
  code: string;
  name: string;
  description: string | null;
  is_gateway: boolean;
  is_lock: boolean;
  is_active: boolean;
  sort_order: number;
}

export interface DeviceAssignmentSummary {
  room_id: string;
  assigned_at: string;
  room?: { id: string; name: string; property_id: string } | null;
}

export interface DeviceRow {
  id: string;
  tenant_id: string;
  parent_device_id: string | null;
  device_name: string;
  category_code: string;
  protocol: string;
  model: string | null;
  manufacturer: string | null;
  is_active: boolean;
  created_at: string;
}

export interface DeviceDetail extends DeviceRow {
  assignment: DeviceAssignmentSummary | null;
  config: Record<string, unknown> | null;
  category?: DeviceCategoryRow | null;
}

export interface DeviceConfigurationRow {
  id: string;
  device_id: string;
  config: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface CreatePropertyRequest {
  name: string;
  address?: string;
  property_type: string;
  timezone?: string;
}

export interface UpdatePropertyRequest {
  id: string;
  name?: string;
  address?: string | null;
  property_type?: string;
  timezone?: string;
}

export interface DeletePropertyRequest {
  id: string;
}

export interface CreateRoomRequest {
  property_id: string;
  name: string;
  room_type: string;
  floor?: number;
}

export interface UpdateRoomRequest {
  id: string;
  name?: string;
  room_type?: string;
  floor?: number | null;
}

export interface DeleteRoomRequest {
  id: string;
}

export interface CreateDeviceRequest {
  device_name: string;
  category_code: string;
  protocol: string;
  parent_device_id?: string;
  model?: string;
  manufacturer?: string;
  is_active?: boolean;
}

export interface UpdateDeviceRequest {
  id: string;
  device_name?: string;
  category_code?: string;
  protocol?: string;
  parent_device_id?: string | null;
  model?: string | null;
  manufacturer?: string | null;
  is_active?: boolean;
}

export interface DeleteDeviceRequest {
  id: string;
}

export interface AssignDeviceRequest {
  device_id: string;
  room_id: string;
}

export interface UnassignDeviceRequest {
  device_id: string;
}

export interface UpsertDeviceConfigRequest {
  device_id: string;
  config: Record<string, unknown>;
}

export type DevicesRoute =
  | "properties"
  | "property"
  | "rooms"
  | "room"
  | "devices"
  | "device"
  | "categories"
  | "assign"
  | "unassign"
  | "device-config";
