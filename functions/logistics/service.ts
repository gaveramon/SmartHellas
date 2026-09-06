import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  CreateCarrierRequest,
  CreateFulfilmentOrderRequest,
  CreateLabelTemplateRequest,
  CreateLogisticsTemplateRequest,
  CreatePackageDefinitionRequest,
  CreateShippingRuleRequest,
  CreateWarehouseRequest,
  DispatchFulfilmentOrderRequest,
  DispatchFulfilmentOrderResponse,
  FulfilmentOrderRow,
  LogisticsTemplateDetail,
  LogisticsTemplateRow,
  PackageDefinitionRow,
  ShippingCarrierRow,
  ShippingLabelTemplateRow,
  ShippingRuleRow,
  UpdateCarrierRequest,
  UpdateFulfilmentOrderRequest,
  UpdateLabelTemplateRequest,
  UpdateLogisticsTemplateRequest,
  UpdatePackageDefinitionRequest,
  UpdateShippingRuleRequest,
  UpdateWarehouseRequest,
  WarehouseRow,
} from "./types.ts";

async function tid(auth: AuthContext): Promise<string> {
  return await requireTenant(auth);
}

export async function listLogisticsTemplates(
  auth: AuthContext,
): Promise<LogisticsTemplateRow[]> {
  await tid(auth);
  return await callModuleApiAuth<LogisticsTemplateRow[]>(
    auth,
    "logistics",
    "list_logistics_templates",
  );
}

export async function getLogisticsTemplate(
  auth: AuthContext,
  id: string,
): Promise<LogisticsTemplateDetail> {
  await tid(auth);
  return await callModuleApiAuth<LogisticsTemplateDetail>(
    auth,
    "logistics",
    "get_logistics_template",
    { id },
  );
}

export async function createLogisticsTemplate(
  auth: AuthContext,
  input: CreateLogisticsTemplateRequest,
): Promise<LogisticsTemplateRow> {
  return await callModuleApiAuth<LogisticsTemplateRow>(
    auth,
    "logistics",
    "create_logistics_template",
    { ...input },
  );
}

export async function updateLogisticsTemplate(
  auth: AuthContext,
  input: UpdateLogisticsTemplateRequest,
): Promise<LogisticsTemplateRow> {
  return await callModuleApiAuth<LogisticsTemplateRow>(
    auth,
    "logistics",
    "update_logistics_template",
    { ...input },
  );
}

export async function deleteLogisticsTemplate(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "logistics", "delete_logistics_template", { id });
}

export async function listPackageDefinitions(
  auth: AuthContext,
  templateId: string,
): Promise<PackageDefinitionRow[]> {
  await tid(auth);
  return await callModuleApiAuth<PackageDefinitionRow[]>(
    auth,
    "logistics",
    "list_package_definitions",
    { template_id: templateId },
  );
}

export async function createPackageDefinition(
  auth: AuthContext,
  input: CreatePackageDefinitionRequest,
): Promise<PackageDefinitionRow> {
  return await callModuleApiAuth<PackageDefinitionRow>(
    auth,
    "logistics",
    "create_package_definition",
    { ...input },
  );
}

export async function updatePackageDefinition(
  auth: AuthContext,
  input: UpdatePackageDefinitionRequest,
): Promise<PackageDefinitionRow> {
  return await callModuleApiAuth<PackageDefinitionRow>(
    auth,
    "logistics",
    "update_package_definition",
    { ...input },
  );
}

export async function deletePackageDefinition(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "logistics", "delete_package_definition", { id });
}

export async function listCarriers(auth: AuthContext): Promise<ShippingCarrierRow[]> {
  await tid(auth);
  return await callModuleApiAuth<ShippingCarrierRow[]>(auth, "logistics", "list_carriers");
}

export async function getCarrier(auth: AuthContext, id: string): Promise<ShippingCarrierRow> {
  await tid(auth);
  return await callModuleApiAuth<ShippingCarrierRow>(auth, "logistics", "get_carrier", { id });
}

export async function createCarrier(
  auth: AuthContext,
  input: CreateCarrierRequest,
): Promise<ShippingCarrierRow> {
  return await callModuleApiAuth<ShippingCarrierRow>(auth, "logistics", "create_carrier", { ...input });
}

export async function updateCarrier(
  auth: AuthContext,
  input: UpdateCarrierRequest,
): Promise<ShippingCarrierRow> {
  return await callModuleApiAuth<ShippingCarrierRow>(auth, "logistics", "update_carrier", { ...input });
}

export async function deleteCarrier(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "logistics", "delete_carrier", { id });
}

export async function listWarehouses(auth: AuthContext): Promise<WarehouseRow[]> {
  await tid(auth);
  return await callModuleApiAuth<WarehouseRow[]>(auth, "logistics", "list_warehouses");
}

export async function getWarehouse(auth: AuthContext, id: string): Promise<WarehouseRow> {
  await tid(auth);
  return await callModuleApiAuth<WarehouseRow>(auth, "logistics", "get_warehouse", { id });
}

export async function createWarehouse(
  auth: AuthContext,
  input: CreateWarehouseRequest,
): Promise<WarehouseRow> {
  return await callModuleApiAuth<WarehouseRow>(auth, "logistics", "create_warehouse", { ...input });
}

export async function updateWarehouse(
  auth: AuthContext,
  input: UpdateWarehouseRequest,
): Promise<WarehouseRow> {
  return await callModuleApiAuth<WarehouseRow>(auth, "logistics", "update_warehouse", { ...input });
}

export async function deleteWarehouse(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "logistics", "delete_warehouse", { id });
}

export async function listLabelTemplates(
  auth: AuthContext,
  carrierId?: string,
): Promise<ShippingLabelTemplateRow[]> {
  await tid(auth);
  return await callModuleApiAuth<ShippingLabelTemplateRow[]>(
    auth,
    "logistics",
    "list_label_templates",
    carrierId ? { carrier_id: carrierId } : {},
  );
}

export async function createLabelTemplate(
  auth: AuthContext,
  input: CreateLabelTemplateRequest,
): Promise<ShippingLabelTemplateRow> {
  return await callModuleApiAuth<ShippingLabelTemplateRow>(
    auth,
    "logistics",
    "create_label_template",
    { ...input },
  );
}

export async function updateLabelTemplate(
  auth: AuthContext,
  input: UpdateLabelTemplateRequest,
): Promise<ShippingLabelTemplateRow> {
  return await callModuleApiAuth<ShippingLabelTemplateRow>(
    auth,
    "logistics",
    "update_label_template",
    { ...input },
  );
}

export async function deleteLabelTemplate(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "logistics", "delete_label_template", { id });
}

export async function listShippingRules(auth: AuthContext): Promise<ShippingRuleRow[]> {
  await tid(auth);
  return await callModuleApiAuth<ShippingRuleRow[]>(auth, "logistics", "list_shipping_rules");
}

export async function createShippingRule(
  auth: AuthContext,
  input: CreateShippingRuleRequest,
): Promise<ShippingRuleRow> {
  return await callModuleApiAuth<ShippingRuleRow>(
    auth,
    "logistics",
    "create_shipping_rule",
    { ...input },
  );
}

export async function updateShippingRule(
  auth: AuthContext,
  input: UpdateShippingRuleRequest,
): Promise<ShippingRuleRow> {
  return await callModuleApiAuth<ShippingRuleRow>(
    auth,
    "logistics",
    "update_shipping_rule",
    { ...input },
  );
}

export async function deleteShippingRule(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "logistics", "delete_shipping_rule", { id });
}

export async function listFulfilmentOrders(
  auth: AuthContext,
  status?: string,
  propertyId?: string,
): Promise<FulfilmentOrderRow[]> {
  await tid(auth);
  const payload: Record<string, string> = {};
  if (status) payload.status = status;
  if (propertyId) payload.property_id = propertyId;
  return await callModuleApiAuth<FulfilmentOrderRow[]>(
    auth,
    "logistics",
    "list_fulfilment_orders",
    payload,
  );
}

export async function getFulfilmentOrder(
  auth: AuthContext,
  id: string,
): Promise<FulfilmentOrderRow> {
  await tid(auth);
  return await callModuleApiAuth<FulfilmentOrderRow>(
    auth,
    "logistics",
    "get_fulfilment_order",
    { id },
  );
}

export async function createFulfilmentOrder(
  auth: AuthContext,
  input: CreateFulfilmentOrderRequest,
): Promise<FulfilmentOrderRow> {
  return await callModuleApiAuth<FulfilmentOrderRow>(
    auth,
    "logistics",
    "create_fulfilment_order",
    { ...input },
  );
}

export async function updateFulfilmentOrder(
  auth: AuthContext,
  input: UpdateFulfilmentOrderRequest,
): Promise<FulfilmentOrderRow> {
  return await callModuleApiAuth<FulfilmentOrderRow>(
    auth,
    "logistics",
    "update_fulfilment_order",
    { ...input },
  );
}

export async function deleteFulfilmentOrder(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "logistics", "delete_fulfilment_order", { id });
}

export async function dispatchFulfilmentOrder(
  auth: AuthContext,
  input: DispatchFulfilmentOrderRequest,
): Promise<DispatchFulfilmentOrderResponse> {
  return await callModuleApiAuth<DispatchFulfilmentOrderResponse>(
    auth,
    "logistics",
    "dispatch_fulfilment_order",
    { ...input },
  );
}
