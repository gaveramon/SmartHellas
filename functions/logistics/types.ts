export interface LogisticsTemplateRow {
  id: string;
  tenant_id: string | null;
  is_system: boolean;
  name: string;
  description: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface PackageDefinitionRow {
  id: string;
  template_id: string;
  device_bundle_id: string;
  name: string;
  description: string | null;
}

export interface ShippingCarrierRow {
  id: string;
  name: string;
  provider_code: string | null;
  is_active: boolean;
  created_at: string;
}

export interface WarehouseRow {
  id: string;
  tenant_id: string | null;
  is_system: boolean;
  name: string;
  address: string | null;
  country_code: string;
  default_carrier_id: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface ShippingLabelTemplateRow {
  id: string;
  carrier_id: string;
  name: string;
  label_format: string;
  service_code: string | null;
  config: Record<string, unknown>;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface ShippingRuleRow {
  id: string;
  tenant_id: string | null;
  is_system: boolean;
  carrier_id: string | null;
  rule_name: string;
  rule_config: Record<string, unknown>;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface FulfilmentOrderRow {
  id: string;
  tenant_id: string;
  property_id: string;
  package_definition_id: string | null;
  device_bundle_id: string | null;
  carrier_id: string | null;
  warehouse_id: string | null;
  label_template_id: string | null;
  customer_proposal_id: string | null;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface LogisticsTemplateDetail {
  template: LogisticsTemplateRow;
  packages: PackageDefinitionRow[];
}

export interface CreateLogisticsTemplateRequest {
  name: string;
  description?: string;
  is_active?: boolean;
}

export interface UpdateLogisticsTemplateRequest {
  id: string;
  name?: string;
  description?: string | null;
  is_active?: boolean;
}

export interface CreatePackageDefinitionRequest {
  template_id: string;
  device_bundle_id: string;
  name: string;
  description?: string;
}

export interface UpdatePackageDefinitionRequest {
  id: string;
  name?: string;
  description?: string | null;
}

export interface CreateWarehouseRequest {
  name: string;
  address?: string;
  country_code?: string;
  default_carrier_id?: string;
  is_active?: boolean;
}

export interface UpdateWarehouseRequest {
  id: string;
  name?: string;
  address?: string | null;
  country_code?: string;
  default_carrier_id?: string | null;
  is_active?: boolean;
}

export interface CreateShippingRuleRequest {
  rule_name: string;
  carrier_id?: string;
  rule_config?: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateShippingRuleRequest {
  id: string;
  rule_name?: string;
  carrier_id?: string | null;
  rule_config?: Record<string, unknown>;
  is_active?: boolean;
}

export interface CreateFulfilmentOrderRequest {
  property_id: string;
  package_definition_id?: string;
  device_bundle_id?: string;
  carrier_id?: string;
  warehouse_id?: string;
  label_template_id?: string;
  customer_proposal_id?: string;
  status?: string;
}

export interface UpdateFulfilmentOrderRequest {
  id: string;
  property_id?: string;
  package_definition_id?: string | null;
  device_bundle_id?: string | null;
  carrier_id?: string | null;
  warehouse_id?: string | null;
  label_template_id?: string | null;
  customer_proposal_id?: string | null;
  status?: string;
}

export interface DispatchFulfilmentOrderRequest {
  fulfilment_order_id: string;
  payload?: Record<string, unknown>;
}

export interface DispatchFulfilmentOrderResponse {
  queued: true;
  dispatch_queue_id: string;
  fulfilment_order_id: string;
}

export interface CreateCarrierRequest {
  name: string;
  provider_code?: string;
  is_active?: boolean;
}

export interface UpdateCarrierRequest {
  id: string;
  name?: string;
  provider_code?: string | null;
  is_active?: boolean;
}

export interface CreateLabelTemplateRequest {
  carrier_id: string;
  name: string;
  label_format?: string;
  service_code?: string;
  config?: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateLabelTemplateRequest {
  id: string;
  name?: string;
  label_format?: string;
  service_code?: string | null;
  config?: Record<string, unknown>;
  is_active?: boolean;
}
