import { ValidationError } from "../shared/errors.ts";
import { optionalEnum } from "../shared/validation.ts";
import type {
  CreateCarrierRequest,
  CreateFulfilmentOrderRequest,
  CreateLabelTemplateRequest,
  CreateLogisticsTemplateRequest,
  CreatePackageDefinitionRequest,
  CreateShippingRuleRequest,
  CreateWarehouseRequest,
  DispatchFulfilmentOrderRequest,
  UpdateCarrierRequest,
  UpdateFulfilmentOrderRequest,
  UpdateLabelTemplateRequest,
  UpdateLogisticsTemplateRequest,
  UpdatePackageDefinitionRequest,
  UpdateShippingRuleRequest,
  UpdateWarehouseRequest,
} from "./types.ts";

export { optionalEnumQuery } from "../shared/validation.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const FULFILMENT_STATUSES = [
  "draft",
  "ready_to_ship",
  "dispatched",
  "delivered",
  "cancelled",
] as const;

export const LABEL_FORMATS = ["pdf", "zpl", "png"] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("logistics");
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

export function parseCreateLogisticsTemplateBody(
  body: unknown,
): CreateLogisticsTemplateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateLogisticsTemplateRequest = {
    name: requireStringField(r, "name"),
  };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateLogisticsTemplateBody(
  body: unknown,
): UpdateLogisticsTemplateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateLogisticsTemplateRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreatePackageDefinitionBody(
  body: unknown,
): CreatePackageDefinitionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreatePackageDefinitionRequest = {
    template_id: requireUuidField(r, "template_id"),
    device_bundle_id: requireUuidField(r, "device_bundle_id"),
    name: requireStringField(r, "name"),
  };
  if (r.description !== undefined) result.description = String(r.description);
  return result;
}

export function parseUpdatePackageDefinitionBody(
  body: unknown,
): UpdatePackageDefinitionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePackageDefinitionRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  return result;
}

export function parseCreateWarehouseBody(body: unknown): CreateWarehouseRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateWarehouseRequest = { name: requireStringField(r, "name") };
  if (r.address !== undefined) result.address = String(r.address);
  if (r.country_code !== undefined) result.country_code = String(r.country_code);
  if (r.default_carrier_id !== undefined) {
    result.default_carrier_id = requireUuidField(r, "default_carrier_id");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateWarehouseBody(body: unknown): UpdateWarehouseRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateWarehouseRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.address !== undefined) result.address = r.address as string | null;
  if (r.country_code !== undefined) result.country_code = String(r.country_code);
  if (r.default_carrier_id !== undefined) {
    result.default_carrier_id =
      r.default_carrier_id === null ? null : requireUuidField(r, "default_carrier_id");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateShippingRuleBody(body: unknown): CreateShippingRuleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateShippingRuleRequest = {
    rule_name: requireStringField(r, "rule_name"),
  };
  if (r.carrier_id !== undefined) result.carrier_id = requireUuidField(r, "carrier_id");
  if (r.rule_config !== undefined) result.rule_config = requireJsonObject(r.rule_config, "rule_config");
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateShippingRuleBody(body: unknown): UpdateShippingRuleRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateShippingRuleRequest = { id: requireUuidField(r, "id") };
  if (r.rule_name !== undefined) result.rule_name = String(r.rule_name);
  if (r.carrier_id !== undefined) {
    result.carrier_id = r.carrier_id === null ? null : requireUuidField(r, "carrier_id");
  }
  if (r.rule_config !== undefined) result.rule_config = requireJsonObject(r.rule_config, "rule_config");
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateFulfilmentOrderBody(body: unknown): CreateFulfilmentOrderRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateFulfilmentOrderRequest = {
    property_id: requireUuidField(r, "property_id"),
  };
  if (r.package_definition_id !== undefined) {
    result.package_definition_id = requireUuidField(r, "package_definition_id");
  }
  if (r.device_bundle_id !== undefined) {
    result.device_bundle_id = requireUuidField(r, "device_bundle_id");
  }
  if (!result.package_definition_id && !result.device_bundle_id) {
    throw new ValidationError("package_definition_id or device_bundle_id is required");
  }
  if (r.carrier_id !== undefined) result.carrier_id = requireUuidField(r, "carrier_id");
  if (r.warehouse_id !== undefined) result.warehouse_id = requireUuidField(r, "warehouse_id");
  if (r.label_template_id !== undefined) {
    result.label_template_id = requireUuidField(r, "label_template_id");
  }
  if (r.customer_proposal_id !== undefined) {
    result.customer_proposal_id = requireUuidField(r, "customer_proposal_id");
  }
  if (r.status !== undefined) {
    result.status = optionalEnum(r.status, "status", FULFILMENT_STATUSES);
  }
  return result;
}

export function parseUpdateFulfilmentOrderBody(body: unknown): UpdateFulfilmentOrderRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateFulfilmentOrderRequest = { id: requireUuidField(r, "id") };
  if (r.property_id !== undefined) result.property_id = requireUuidField(r, "property_id");
  if (r.package_definition_id !== undefined) {
    result.package_definition_id =
      r.package_definition_id === null ? null : requireUuidField(r, "package_definition_id");
  }
  if (r.device_bundle_id !== undefined) {
    result.device_bundle_id =
      r.device_bundle_id === null ? null : requireUuidField(r, "device_bundle_id");
  }
  if (r.carrier_id !== undefined) {
    result.carrier_id = r.carrier_id === null ? null : requireUuidField(r, "carrier_id");
  }
  if (r.warehouse_id !== undefined) {
    result.warehouse_id = r.warehouse_id === null ? null : requireUuidField(r, "warehouse_id");
  }
  if (r.label_template_id !== undefined) {
    result.label_template_id =
      r.label_template_id === null ? null : requireUuidField(r, "label_template_id");
  }
  if (r.customer_proposal_id !== undefined) {
    result.customer_proposal_id =
      r.customer_proposal_id === null ? null : requireUuidField(r, "customer_proposal_id");
  }
  if (r.status !== undefined) {
    result.status = optionalEnum(r.status, "status", FULFILMENT_STATUSES);
  }
  return result;
}

export function parseDispatchFulfilmentBody(body: unknown): DispatchFulfilmentOrderRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: DispatchFulfilmentOrderRequest = {
    fulfilment_order_id: requireUuidField(r, "fulfilment_order_id"),
  };
  if (r.payload !== undefined) result.payload = requireJsonObject(r.payload, "payload");
  return result;
}

export function parseCreateCarrierBody(body: unknown): CreateCarrierRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateCarrierRequest = { name: requireStringField(r, "name") };
  if (r.provider_code !== undefined) result.provider_code = String(r.provider_code);
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateCarrierBody(body: unknown): UpdateCarrierRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateCarrierRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.provider_code !== undefined) {
    result.provider_code = r.provider_code as string | null;
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateLabelTemplateBody(body: unknown): CreateLabelTemplateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateLabelTemplateRequest = {
    carrier_id: requireUuidField(r, "carrier_id"),
    name: requireStringField(r, "name"),
  };
  if (r.label_format !== undefined) {
    result.label_format = optionalEnum(r.label_format, "label_format", LABEL_FORMATS);
  }
  if (r.service_code !== undefined) result.service_code = String(r.service_code);
  if (r.config !== undefined) result.config = requireJsonObject(r.config, "config");
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateLabelTemplateBody(body: unknown): UpdateLabelTemplateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateLabelTemplateRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.label_format !== undefined) {
    result.label_format = optionalEnum(r.label_format, "label_format", LABEL_FORMATS);
  }
  if (r.service_code !== undefined) result.service_code = r.service_code as string | null;
  if (r.config !== undefined) result.config = requireJsonObject(r.config, "config");
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}
