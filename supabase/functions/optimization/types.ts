export interface OptimizationRuleRow {
  id: string;
  tenant_id: string;
  rule_name: string;
  description: string | null;
  category: string | null;
  rule_config: Record<string, unknown>;
  is_active: boolean;
  created_at: string;
}

export interface InsightEventRow {
  id: string;
  tenant_id: string;
  property_id: string | null;
  insight_type: string;
  severity: string;
  message: string | null;
  metadata: Record<string, unknown> | null;
  dedup_key: string | null;
  confidence: number | null;
  ai_metadata: Record<string, unknown> | null;
  related_recommendation_id: string | null;
  created_at: string;
}

export interface OptimizationRecommendationRow {
  id: string;
  tenant_id: string;
  property_id: string | null;
  source_rule_id: string | null;
  source_insight_id: string | null;
  recommendation_type: string;
  severity: string;
  status: string;
  explanation: Record<string, unknown> | null;
  suggested_changes: Record<string, unknown> | null;
  confidence: number | null;
  dedup_key: string | null;
  ai_metadata: Record<string, unknown> | null;
  customer_proposal_id: string | null;
  created_at: string;
}

export interface DeviceUsageScoreRow {
  id: string;
  tenant_id: string;
  device_id: string;
  score: number | null;
  category: string;
  score_period: string;
  calculated_at: string;
}

export interface EnergyProfileRow {
  id: string;
  tenant_id: string;
  property_id: string;
  period_start: string;
  period_end: string;
  consumption_unit: string;
  baseline_consumption: number | null;
  optimized_consumption: number | null;
  potential_savings_percent: number | null;
  computed_at: string;
}

export interface CreateOptimizationRuleRequest {
  rule_name: string;
  description?: string;
  category?: string;
  rule_config: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateOptimizationRuleRequest {
  id: string;
  rule_name?: string;
  description?: string | null;
  category?: string | null;
  rule_config?: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateRecommendationRequest {
  id: string;
  status?: string;
}
