import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  ChangePlanRequest,
  ChangePlanResponse,
  CreateFeatureEntitlementRequest,
  CreatePlanPricingRequest,
  CreateProductPlanRequest,
  CreateUpsellRuleRequest,
  FeatureEntitlementRow,
  PlanDetail,
  PlanPricingRow,
  ProductPlanRow,
  TenantEntitlementsResponse,
  UpdateFeatureEntitlementRequest,
  UpdatePlanPricingRequest,
  UpdateProductPlanRequest,
  UpdateUpsellRuleRequest,
  UpsellRuleRow,
} from "./types.ts";

async function tid(auth: AuthContext): Promise<string> {
  return await requireTenant(auth);
}

export async function listProductPlans(auth: AuthContext): Promise<ProductPlanRow[]> {
  await tid(auth);
  return await callModuleApiAuth<ProductPlanRow[]>(auth, "commerce", "list_product_plans");
}

export async function getProductPlan(auth: AuthContext, id: string): Promise<PlanDetail> {
  await tid(auth);
  return await callModuleApiAuth<PlanDetail>(auth, "commerce", "get_product_plan", { id });
}

export async function createProductPlan(
  auth: AuthContext,
  input: CreateProductPlanRequest,
): Promise<ProductPlanRow> {
  return await callModuleApiAuth<ProductPlanRow>(auth, "commerce", "create_product_plan", { ...input });
}

export async function updateProductPlan(
  auth: AuthContext,
  input: UpdateProductPlanRequest,
): Promise<ProductPlanRow> {
  return await callModuleApiAuth<ProductPlanRow>(auth, "commerce", "update_product_plan", { ...input });
}

export async function deleteProductPlan(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "commerce", "delete_product_plan", { id });
}

export async function listPlanPricing(
  auth: AuthContext,
  planId: string,
): Promise<PlanPricingRow[]> {
  await tid(auth);
  return await callModuleApiAuth<PlanPricingRow[]>(auth, "commerce", "list_plan_pricing", {
    plan_id: planId,
  });
}

export async function createPlanPricing(
  auth: AuthContext,
  input: CreatePlanPricingRequest,
): Promise<PlanPricingRow> {
  return await callModuleApiAuth<PlanPricingRow>(auth, "commerce", "create_plan_pricing", { ...input });
}

export async function updatePlanPricing(
  auth: AuthContext,
  input: UpdatePlanPricingRequest,
): Promise<PlanPricingRow> {
  return await callModuleApiAuth<PlanPricingRow>(auth, "commerce", "update_plan_pricing", { ...input });
}

export async function deletePlanPricing(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "commerce", "delete_plan_pricing", { id });
}

export async function listFeatureEntitlements(
  auth: AuthContext,
  planId?: string,
): Promise<FeatureEntitlementRow[]> {
  await tid(auth);
  return await callModuleApiAuth<FeatureEntitlementRow[]>(
    auth,
    "commerce",
    "list_feature_entitlements",
    planId ? { plan_id: planId } : {},
  );
}

export async function createFeatureEntitlement(
  auth: AuthContext,
  input: CreateFeatureEntitlementRequest,
): Promise<FeatureEntitlementRow> {
  return await callModuleApiAuth<FeatureEntitlementRow>(
    auth,
    "commerce",
    "create_feature_entitlement",
    { ...input },
  );
}

export async function updateFeatureEntitlement(
  auth: AuthContext,
  input: UpdateFeatureEntitlementRequest,
): Promise<FeatureEntitlementRow> {
  return await callModuleApiAuth<FeatureEntitlementRow>(
    auth,
    "commerce",
    "update_feature_entitlement",
    { ...input },
  );
}

export async function deleteFeatureEntitlement(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "commerce", "delete_feature_entitlement", { id });
}

export async function listUpsellRules(
  auth: AuthContext,
  triggerEvent?: string,
): Promise<UpsellRuleRow[]> {
  await tid(auth);
  return await callModuleApiAuth<UpsellRuleRow[]>(
    auth,
    "commerce",
    "list_upsell_rules",
    triggerEvent ? { trigger_event: triggerEvent } : {},
  );
}

export async function createUpsellRule(
  auth: AuthContext,
  input: CreateUpsellRuleRequest,
): Promise<UpsellRuleRow> {
  return await callModuleApiAuth<UpsellRuleRow>(auth, "commerce", "create_upsell_rule", { ...input });
}

export async function updateUpsellRule(
  auth: AuthContext,
  input: UpdateUpsellRuleRequest,
): Promise<UpsellRuleRow> {
  return await callModuleApiAuth<UpsellRuleRow>(auth, "commerce", "update_upsell_rule", { ...input });
}

export async function deleteUpsellRule(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "commerce", "delete_upsell_rule", { id });
}

export async function getTenantEntitlements(
  auth: AuthContext,
): Promise<TenantEntitlementsResponse> {
  await tid(auth);
  return await callModuleApiAuth<TenantEntitlementsResponse>(
    auth,
    "commerce",
    "get_tenant_entitlements",
  );
}

export async function changeTenantPlan(
  auth: AuthContext,
  input: ChangePlanRequest,
): Promise<ChangePlanResponse> {
  return await callModuleApiAuth<ChangePlanResponse>(auth, "commerce", "change_plan", { ...input });
}
