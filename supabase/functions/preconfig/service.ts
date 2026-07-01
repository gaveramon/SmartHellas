import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  BlueprintDetail,
  BundleDeviceRow,
  CreateBlueprintRequest,
  CreateBlueprintStepRequest,
  CreateBundleDeviceRequest,
  CreateDeviceBundleRequest,
  CreatePreconfigDeviceMapRequest,
  CreatePreconfigTemplateRequest,
  DeviceBundleRow,
  OnboardingBlueprintRow,
  OnboardingBlueprintStepRow,
  PreconfigDeviceMapRow,
  PreconfigTemplateDetail,
  PreconfigTemplateRow,
  UpdateBlueprintRequest,
  UpdateBlueprintStepRequest,
  UpdateBundleDeviceRequest,
  UpdateDeviceBundleRequest,
  UpdatePreconfigDeviceMapRequest,
  UpdatePreconfigTemplateRequest,
} from "./types.ts";

function tid(auth: AuthContext): string {
  return requireTenant(auth);
}

export async function createBlueprintStep(auth: AuthContext, input: CreateBlueprintStepRequest): Promise<OnboardingBlueprintStepRow> {
  return await callModuleApiAuth<OnboardingBlueprintStepRow>(auth, "preconfig", "create_blueprint_step", { ...input });
}

export async function createBundleDevice(auth: AuthContext, input: CreateBundleDeviceRequest): Promise<BundleDeviceRow> {
  return await callModuleApiAuth<BundleDeviceRow>(auth, "preconfig", "create_bundle_device", { ...input });
}

export async function createDeviceBundle(auth: AuthContext, input: CreateDeviceBundleRequest): Promise<DeviceBundleRow> {
  return await callModuleApiAuth<DeviceBundleRow>(auth, "preconfig", "create_device_bundle", { ...input });
}

export async function createOnboardingBlueprint(auth: AuthContext, input: CreateBlueprintRequest): Promise<OnboardingBlueprintRow> {
  return await callModuleApiAuth<OnboardingBlueprintRow>(auth, "preconfig", "create_onboarding_blueprint", { ...input });
}

export async function createPreconfigDeviceMap(auth: AuthContext, input: CreatePreconfigDeviceMapRequest): Promise<PreconfigDeviceMapRow> {
  return await callModuleApiAuth<PreconfigDeviceMapRow>(auth, "preconfig", "create_preconfig_device_map", { ...input });
}

export async function createPreconfigTemplate(auth: AuthContext, input: CreatePreconfigTemplateRequest): Promise<PreconfigTemplateRow> {
  return await callModuleApiAuth<PreconfigTemplateRow>(auth, "preconfig", "create_preconfig_template", { ...input });
}

export async function deleteBlueprintStep(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "preconfig", "delete_blueprint_step", { id: id });
}

export async function deleteBundleDevice(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "preconfig", "delete_bundle_device", { id: id });
}

export async function deleteDeviceBundle(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "preconfig", "delete_device_bundle", { id: id });
}

export async function deleteOnboardingBlueprint(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "preconfig", "delete_onboarding_blueprint", { id: id });
}

export async function deletePreconfigDeviceMap(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "preconfig", "delete_preconfig_device_map", { id: id });
}

export async function deletePreconfigTemplate(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "preconfig", "delete_preconfig_template", { id: id });
}

export async function getDeviceBundleByCode(auth: AuthContext, code: string, version?: number): Promise<DeviceBundleRow> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  payload.code = code;
  if (version !== undefined) payload.version = version;
  return await callModuleApiAuth<DeviceBundleRow>(auth, "preconfig", "get_device_bundle", payload);
}

export async function getDeviceBundleById(auth: AuthContext, id: string): Promise<DeviceBundleRow> {
  tid(auth);
  return await callModuleApiAuth<DeviceBundleRow>(auth, "preconfig", "get_device_bundle", { id: id });
}

export async function getOnboardingBlueprintByCode(auth: AuthContext, code: string): Promise<BlueprintDetail> {
  tid(auth);
  return await callModuleApiAuth<BlueprintDetail>(auth, "preconfig", "get_onboarding_blueprint", { code: code });
}

export async function getOnboardingBlueprintById(auth: AuthContext, id: string): Promise<BlueprintDetail> {
  tid(auth);
  return await callModuleApiAuth<BlueprintDetail>(auth, "preconfig", "get_onboarding_blueprint", { id: id });
}

export async function getPreconfigTemplate(auth: AuthContext, id: string): Promise<PreconfigTemplateDetail> {
  tid(auth);
  return await callModuleApiAuth<PreconfigTemplateDetail>(auth, "preconfig", "get_preconfig_template", { id: id });
}

export async function listBlueprintSteps(auth: AuthContext, blueprintId: string): Promise<OnboardingBlueprintStepRow[]> {
  tid(auth);
  return await callModuleApiAuth<OnboardingBlueprintStepRow[]>(auth, "preconfig", "list_blueprint_steps", { blueprint_id: blueprintId });
}

export async function listBundleDevices(auth: AuthContext, bundleId: string): Promise<BundleDeviceRow[]> {
  tid(auth);
  return await callModuleApiAuth<BundleDeviceRow[]>(auth, "preconfig", "list_bundle_devices", { bundle_id: bundleId });
}

export async function listDeviceBundles(auth: AuthContext, propertyType?: string, activeOnly?: boolean): Promise<DeviceBundleRow[]> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  if (propertyType !== undefined) payload.property_type = propertyType;
  if (activeOnly !== undefined) payload.active_only = activeOnly;
  return await callModuleApiAuth<DeviceBundleRow[]>(auth, "preconfig", "list_device_bundles", payload);
}

export async function listOnboardingBlueprints(auth: AuthContext, propertyType?: string, activeOnly?: boolean): Promise<OnboardingBlueprintRow[]> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  if (propertyType !== undefined) payload.property_type = propertyType;
  if (activeOnly !== undefined) payload.active_only = activeOnly;
  return await callModuleApiAuth<OnboardingBlueprintRow[]>(auth, "preconfig", "list_onboarding_blueprints", payload);
}

export async function listPreconfigDeviceMap(auth: AuthContext, templateId: string): Promise<PreconfigDeviceMapRow[]> {
  tid(auth);
  return await callModuleApiAuth<PreconfigDeviceMapRow[]>(auth, "preconfig", "list_preconfig_device_map", { template_id: templateId });
}

export async function listPreconfigTemplates(auth: AuthContext, propertyType?: string, activeOnly?: boolean): Promise<PreconfigTemplateRow[]> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  if (propertyType !== undefined) payload.property_type = propertyType;
  if (activeOnly !== undefined) payload.active_only = activeOnly;
  return await callModuleApiAuth<PreconfigTemplateRow[]>(auth, "preconfig", "list_preconfig_templates", payload);
}

export async function updateBlueprintStep(auth: AuthContext, input: UpdateBlueprintStepRequest): Promise<OnboardingBlueprintStepRow> {
  return await callModuleApiAuth<OnboardingBlueprintStepRow>(auth, "preconfig", "update_blueprint_step", { ...input });
}

export async function updateBundleDevice(auth: AuthContext, input: UpdateBundleDeviceRequest): Promise<BundleDeviceRow> {
  return await callModuleApiAuth<BundleDeviceRow>(auth, "preconfig", "update_bundle_device", { ...input });
}

export async function updateDeviceBundle(auth: AuthContext, input: UpdateDeviceBundleRequest): Promise<DeviceBundleRow> {
  return await callModuleApiAuth<DeviceBundleRow>(auth, "preconfig", "update_device_bundle", { ...input });
}

export async function updateOnboardingBlueprint(auth: AuthContext, input: UpdateBlueprintRequest): Promise<OnboardingBlueprintRow> {
  return await callModuleApiAuth<OnboardingBlueprintRow>(auth, "preconfig", "update_onboarding_blueprint", { ...input });
}

export async function updatePreconfigDeviceMap(auth: AuthContext, input: UpdatePreconfigDeviceMapRequest): Promise<PreconfigDeviceMapRow> {
  return await callModuleApiAuth<PreconfigDeviceMapRow>(auth, "preconfig", "update_preconfig_device_map", { ...input });
}

export async function updatePreconfigTemplate(auth: AuthContext, input: UpdatePreconfigTemplateRequest): Promise<PreconfigTemplateRow> {
  return await callModuleApiAuth<PreconfigTemplateRow>(auth, "preconfig", "update_preconfig_template", { ...input });
}
