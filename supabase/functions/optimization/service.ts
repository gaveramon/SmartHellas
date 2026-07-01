import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  CreateOptimizationRuleRequest,
  DeviceUsageScoreRow,
  EnergyProfileRow,
  InsightEventRow,
  OptimizationRecommendationRow,
  OptimizationRuleRow,
  UpdateOptimizationRuleRequest,
  UpdateRecommendationRequest,
} from "./types.ts";

function tid(auth: AuthContext): string {
  return requireTenant(auth);
}

export async function createOptimizationRule(auth: AuthContext, input: CreateOptimizationRuleRequest): Promise<OptimizationRuleRow> {
  return await callModuleApiAuth<OptimizationRuleRow>(auth, "optimization", "create_rule", { ...input });
}

export async function deleteOptimizationRule(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "optimization", "delete_rule", { id: id });
}

export async function deleteRecommendation(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "optimization", "delete_recommendation", { id: id });
}

export async function getEnergyProfile(auth: AuthContext, id: string): Promise<EnergyProfileRow> {
  tid(auth);
  return await callModuleApiAuth<EnergyProfileRow>(auth, "optimization", "get_energy_profile", { id: id });
}

export async function getInsightEvent(auth: AuthContext, id: string): Promise<InsightEventRow> {
  tid(auth);
  return await callModuleApiAuth<InsightEventRow>(auth, "optimization", "get_insight_event", { id: id });
}

export async function getOptimizationRule(auth: AuthContext, id: string): Promise<OptimizationRuleRow> {
  tid(auth);
  return await callModuleApiAuth<OptimizationRuleRow>(auth, "optimization", "get_rule", { id: id });
}

export async function getRecommendation(auth: AuthContext, id: string): Promise<OptimizationRecommendationRow> {
  tid(auth);
  return await callModuleApiAuth<OptimizationRecommendationRow>(auth, "optimization", "get_recommendation", { id: id });
}

export async function listDeviceUsageScores(auth: AuthContext, deviceId?: string): Promise<DeviceUsageScoreRow[]> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  if (deviceId !== undefined) payload.device_id = deviceId;
  return await callModuleApiAuth<DeviceUsageScoreRow[]>(auth, "optimization", "list_device_usage_scores", payload);
}

export async function listEnergyProfiles(auth: AuthContext, propertyId?: string): Promise<EnergyProfileRow[]> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  if (propertyId !== undefined) payload.property_id = propertyId;
  return await callModuleApiAuth<EnergyProfileRow[]>(auth, "optimization", "list_energy_profiles", payload);
}

export async function listInsightEvents(auth: AuthContext, propertyId?: string, insightType?: string): Promise<InsightEventRow[]> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  if (propertyId !== undefined) payload.property_id = propertyId;
  if (insightType !== undefined) payload.insight_type = insightType;
  return await callModuleApiAuth<InsightEventRow[]>(auth, "optimization", "list_insight_events", payload);
}

export async function listOptimizationRules(auth: AuthContext): Promise<OptimizationRuleRow[]> {
  tid(auth);
  return await callModuleApiAuth<OptimizationRuleRow[]>(auth, "optimization", "list_rules");
}

export async function listRecommendations(auth: AuthContext, status?: string, propertyId?: string): Promise<OptimizationRecommendationRow[]> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  if (status !== undefined) payload.status = status;
  if (propertyId !== undefined) payload.property_id = propertyId;
  return await callModuleApiAuth<OptimizationRecommendationRow[]>(auth, "optimization", "list_recommendations", payload);
}

export async function updateOptimizationRule(auth: AuthContext, input: UpdateOptimizationRuleRequest): Promise<OptimizationRuleRow> {
  return await callModuleApiAuth<OptimizationRuleRow>(auth, "optimization", "update_rule", { ...input });
}

export async function updateRecommendation(auth: AuthContext, input: UpdateRecommendationRequest): Promise<OptimizationRecommendationRow> {
  return await callModuleApiAuth<OptimizationRecommendationRow>(auth, "optimization", "update_recommendation", { ...input });
}
