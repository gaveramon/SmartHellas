export interface DeviceBundleRow {
  id: string;
  code: string;
  version: number;
  name: string;
  description: string | null;
  property_type: string | null;
  is_active: boolean;
  is_system: boolean;
  created_at: string;
  updated_at: string;
}

export interface BundleDeviceRow {
  id: string;
  bundle_id: string;
  category_code: string;
  quantity: number;
  is_required: boolean;
  config_hint: Record<string, unknown>;
  created_at: string;
}

export interface OnboardingBlueprintRow {
  id: string;
  code: string;
  name: string;
  description: string | null;
  property_type: string | null;
  is_system: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface OnboardingBlueprintStepRow {
  id: string;
  blueprint_id: string;
  step_order: number;
  step_type: string;
  config: Record<string, unknown>;
  created_at: string;
}

export interface BlueprintDetail {
  blueprint: OnboardingBlueprintRow;
  steps: OnboardingBlueprintStepRow[];
}

export interface PreconfigTemplateRow {
  id: string;
  device_bundle_id: string;
  onboarding_blueprint_id: string | null;
  name: string;
  description: string | null;
  property_type: string | null;
  is_active: boolean;
  version: number;
  created_at: string;
  updated_at: string;
}

export interface PreconfigDeviceMapRow {
  id: string;
  template_id: string;
  category_code: string;
  room_type: string;
  recommended_protocol: string | null;
  default_config: Record<string, unknown>;
  created_at: string;
}

export interface PreconfigTemplateDetail {
  template: PreconfigTemplateRow;
  device_map: PreconfigDeviceMapRow[];
  bundle_devices: BundleDeviceRow[];
}

export interface CreateDeviceBundleRequest {
  code: string;
  name: string;
  description?: string;
  property_type?: string;
  version?: number;
  is_active?: boolean;
  is_system?: boolean;
}

export interface UpdateDeviceBundleRequest {
  id: string;
  code?: string;
  name?: string;
  description?: string | null;
  property_type?: string | null;
  version?: number;
  is_active?: boolean;
  is_system?: boolean;
}

export interface CreateBundleDeviceRequest {
  bundle_id: string;
  category_code: string;
  quantity?: number;
  is_required?: boolean;
  config_hint?: Record<string, unknown>;
}

export interface UpdateBundleDeviceRequest {
  id: string;
  quantity?: number;
  is_required?: boolean;
  config_hint?: Record<string, unknown>;
}

export interface CreateBlueprintRequest {
  code: string;
  name: string;
  description?: string;
  property_type?: string;
  is_system?: boolean;
  is_active?: boolean;
}

export interface UpdateBlueprintRequest {
  id: string;
  code?: string;
  name?: string;
  description?: string | null;
  property_type?: string | null;
  is_system?: boolean;
  is_active?: boolean;
}

export interface CreateBlueprintStepRequest {
  blueprint_id: string;
  step_order: number;
  step_type: string;
  config?: Record<string, unknown>;
}

export interface UpdateBlueprintStepRequest {
  id: string;
  step_order?: number;
  step_type?: string;
  config?: Record<string, unknown>;
}

export interface CreatePreconfigTemplateRequest {
  device_bundle_id: string;
  onboarding_blueprint_id?: string;
  name: string;
  description?: string;
  property_type?: string;
  is_active?: boolean;
  version?: number;
}

export interface UpdatePreconfigTemplateRequest {
  id: string;
  device_bundle_id?: string;
  onboarding_blueprint_id?: string | null;
  name?: string;
  description?: string | null;
  property_type?: string | null;
  is_active?: boolean;
  version?: number;
}

export interface CreatePreconfigDeviceMapRequest {
  template_id: string;
  category_code: string;
  room_type: string;
  recommended_protocol?: string;
  default_config?: Record<string, unknown>;
}

export interface UpdatePreconfigDeviceMapRequest {
  id: string;
  category_code?: string;
  room_type?: string;
  recommended_protocol?: string | null;
  default_config?: Record<string, unknown>;
}
