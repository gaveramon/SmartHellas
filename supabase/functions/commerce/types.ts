export interface ProductPlanRow {
  id: string;
  name: string;
  description: string | null;
  tier: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface PlanPricingRow {
  id: string;
  plan_id: string;
  currency: string;
  monthly_price: number | null;
  yearly_price: number | null;
  effective_from: string;
  created_at: string;
}

export interface FeatureEntitlementRow {
  id: string;
  plan_id: string;
  feature_key: string;
  enabled: boolean;
}

export interface UpsellRuleRow {
  id: string;
  tenant_id: string | null;
  trigger_event: string | null;
  recommended_plan_id: string | null;
  rule_config: Record<string, unknown> | null;
  is_active: boolean;
  created_at: string;
}

export interface PlanDetail {
  plan: ProductPlanRow;
  pricing: PlanPricingRow[];
  entitlements: FeatureEntitlementRow[];
}

export interface TenantEntitlementsResponse {
  tenant_id: string;
  plan_id: string | null;
  tier: string | null;
  features: FeatureEntitlementRow[];
}

export interface CreateProductPlanRequest {
  name: string;
  description?: string;
  tier: string;
  is_active?: boolean;
}

export interface UpdateProductPlanRequest {
  id: string;
  name?: string;
  description?: string | null;
  tier?: string;
  is_active?: boolean;
}

export interface CreatePlanPricingRequest {
  plan_id: string;
  currency?: string;
  monthly_price?: number;
  yearly_price?: number;
  effective_from?: string;
}

export interface UpdatePlanPricingRequest {
  id: string;
  currency?: string;
  monthly_price?: number | null;
  yearly_price?: number | null;
  effective_from?: string;
}

export interface CreateFeatureEntitlementRequest {
  plan_id: string;
  feature_key: string;
  enabled?: boolean;
}

export interface UpdateFeatureEntitlementRequest {
  id: string;
  feature_key?: string;
  enabled?: boolean;
}

export interface CreateUpsellRuleRequest {
  trigger_event?: string;
  recommended_plan_id?: string;
  rule_config?: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateUpsellRuleRequest {
  id: string;
  trigger_event?: string | null;
  recommended_plan_id?: string | null;
  rule_config?: Record<string, unknown> | null;
  is_active?: boolean;
}

export interface ChangePlanRequest {
  plan_id: string;
}

export interface ChangePlanResponse {
  subscription_id: string;
  plan_id: string;
  tier: string;
  status: string;
}
