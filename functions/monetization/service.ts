import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  ConversionEventRow,
  ConversionScoreRow,
  CreatePackageRequest,
  CreateProposalItemRequest,
  CreateProposalRequest,
  CreateUpsellCampaignRequest,
  CustomerProposalRow,
  MonetizationPackageRow,
  ProposalDetail,
  ProposalItemRow,
  ServiceActivationStateRow,
  UpdatePackageRequest,
  UpdateProposalItemRequest,
  UpdateProposalRequest,
  UpdateUpsellCampaignRequest,
  UpsellCampaignRow,
} from "./types.ts";

async function tid(auth: AuthContext): Promise<string> {
  return await requireTenant(auth);
}

export async function createPackage(auth: AuthContext, input: CreatePackageRequest): Promise<MonetizationPackageRow> {
  return await callModuleApiAuth<MonetizationPackageRow>(auth, "monetization", "create_package", { ...input });
}

export async function createProposal(auth: AuthContext, input: CreateProposalRequest): Promise<CustomerProposalRow> {
  return await callModuleApiAuth<CustomerProposalRow>(auth, "monetization", "create_proposal", { ...input });
}

export async function createProposalItem(auth: AuthContext, input: CreateProposalItemRequest): Promise<ProposalItemRow> {
  return await callModuleApiAuth<ProposalItemRow>(auth, "monetization", "create_proposal_item", { ...input });
}

export async function createUpsellCampaign(auth: AuthContext, input: CreateUpsellCampaignRequest): Promise<UpsellCampaignRow> {
  return await callModuleApiAuth<UpsellCampaignRow>(auth, "monetization", "create_upsell_campaign", { ...input });
}

export async function deletePackage(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "monetization", "delete_package", { id: id });
}

export async function deleteProposal(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "monetization", "delete_proposal", { id: id });
}

export async function deleteProposalItem(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "monetization", "delete_proposal_item", { id: id });
}

export async function deleteUpsellCampaign(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "monetization", "delete_upsell_campaign", { id: id });
}

export async function getPackage(auth: AuthContext, id: string): Promise<MonetizationPackageRow> {
  await tid(auth);
  return await callModuleApiAuth<MonetizationPackageRow>(auth, "monetization", "get_package", { id: id });
}

export async function getProposal(auth: AuthContext, id: string): Promise<ProposalDetail> {
  await tid(auth);
  return await callModuleApiAuth<ProposalDetail>(auth, "monetization", "get_proposal", { id: id });
}

export async function getUpsellCampaign(auth: AuthContext, id: string): Promise<UpsellCampaignRow> {
  await tid(auth);
  return await callModuleApiAuth<UpsellCampaignRow>(auth, "monetization", "get_upsell_campaign", { id: id });
}

export async function listActivationState(auth: AuthContext, propertyId?: string, serviceType?: string): Promise<ServiceActivationStateRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (propertyId !== undefined) payload.property_id = propertyId;
  if (serviceType !== undefined) payload.service_type = serviceType;
  return await callModuleApiAuth<ServiceActivationStateRow[]>(auth, "monetization", "list_activation_state", payload);
}

export async function listConversionEvents(auth: AuthContext, proposalId?: string, eventType?: string, limit?: number): Promise<ConversionEventRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (proposalId !== undefined) payload.proposal_id = proposalId;
  if (eventType !== undefined) payload.event_type = eventType;
  if (limit !== undefined) payload.limit = limit;
  return await callModuleApiAuth<ConversionEventRow[]>(auth, "monetization", "list_conversion_events", payload);
}

export async function listConversionScores(auth: AuthContext, propertyId?: string, limit?: number): Promise<ConversionScoreRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (propertyId !== undefined) payload.property_id = propertyId;
  if (limit !== undefined) payload.limit = limit;
  return await callModuleApiAuth<ConversionScoreRow[]>(auth, "monetization", "list_conversion_scores", payload);
}

export async function listPackages(auth: AuthContext, activeOnly?: boolean): Promise<MonetizationPackageRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (activeOnly !== undefined) payload.active_only = activeOnly;
  return await callModuleApiAuth<MonetizationPackageRow[]>(auth, "monetization", "list_packages", payload);
}

export async function listProposalItems(auth: AuthContext, proposalId: string): Promise<ProposalItemRow[]> {
  await tid(auth);
  return await callModuleApiAuth<ProposalItemRow[]>(auth, "monetization", "list_proposal_items", { proposal_id: proposalId });
}

export async function listProposals(auth: AuthContext, status?: string, propertyId?: string): Promise<CustomerProposalRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (status !== undefined) payload.status = status;
  if (propertyId !== undefined) payload.property_id = propertyId;
  return await callModuleApiAuth<CustomerProposalRow[]>(auth, "monetization", "list_proposals", payload);
}

export async function listUpsellCampaigns(auth: AuthContext, triggerEvent?: string, activeOnly?: boolean): Promise<UpsellCampaignRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (triggerEvent !== undefined) payload.trigger_event = triggerEvent;
  if (activeOnly !== undefined) payload.active_only = activeOnly;
  return await callModuleApiAuth<UpsellCampaignRow[]>(auth, "monetization", "list_upsell_campaigns", payload);
}

export async function updatePackage(auth: AuthContext, input: UpdatePackageRequest): Promise<MonetizationPackageRow> {
  return await callModuleApiAuth<MonetizationPackageRow>(auth, "monetization", "update_package", { ...input });
}

export async function updateProposal(auth: AuthContext, input: UpdateProposalRequest): Promise<CustomerProposalRow> {
  return await callModuleApiAuth<CustomerProposalRow>(auth, "monetization", "update_proposal", { ...input });
}

export async function updateProposalItem(auth: AuthContext, input: UpdateProposalItemRequest): Promise<ProposalItemRow> {
  return await callModuleApiAuth<ProposalItemRow>(auth, "monetization", "update_proposal_item", { ...input });
}

export async function updateUpsellCampaign(auth: AuthContext, input: UpdateUpsellCampaignRequest): Promise<UpsellCampaignRow> {
  return await callModuleApiAuth<UpsellCampaignRow>(auth, "monetization", "update_upsell_campaign", { ...input });
}
