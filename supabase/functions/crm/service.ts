import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  CreateCampaignRequest,
  CreateCompanyRequest,
  CreateCompanyTenantRequest,
  CreateContactCompanyRequest,
  CreateContactRequest,
  CreateContactTenantRequest,
  CreateCustomFieldRequest,
  CreateInteractionRequest,
  CreateLeadRequest,
  CreateListMemberRequest,
  CreateListRequest,
  CreateNoteRequest,
  CreateOpportunityRequest,
  CreatePipelineRequest,
  CreatePipelineStageRequest,
  CreateTagAssignmentRequest,
  CreateTagRequest,
  CreateTaskRequest,
  CrmCampaignRow,
  CrmCompanyRow,
  CrmCompanyTenantRow,
  CrmContactCompanyRow,
  CrmContactRow,
  CrmContactTenantRow,
  CrmCustomFieldRow,
  CrmCustomFieldValueRow,
  CrmInteractionRow,
  CrmLeadRow,
  CrmListMemberRow,
  CrmListRow,
  CrmNoteRow,
  CrmOpportunityRow,
  CrmPipelineRow,
  CrmPipelineStageRow,
  CrmTagAssignmentRow,
  CrmTagRow,
  CrmTaskRow,
  PipelineDetail,
  UpdateCampaignRequest,
  UpdateCompanyRequest,
  UpdateCompanyTenantRequest,
  UpdateContactCompanyRequest,
  UpdateContactRequest,
  UpdateContactTenantRequest,
  UpdateCustomFieldRequest,
  UpdateCustomFieldValueRequest,
  UpdateLeadRequest,
  UpdateListRequest,
  UpdateNoteRequest,
  UpdateOpportunityRequest,
  UpdatePipelineRequest,
  UpdatePipelineStageRequest,
  UpdateTagRequest,
  UpdateTaskRequest,
  UpsertCustomFieldValueRequest,
} from "./types.ts";

async function tid(auth: AuthContext): Promise<string> {
  return await requireTenant(auth);
}

export async function createCampaign(auth: AuthContext, input: CreateCampaignRequest): Promise<CrmCampaignRow> {
  return await callModuleApiAuth<CrmCampaignRow>(auth, "crm", "create_campaign", { ...input });
}

export async function createCompany(auth: AuthContext, input: CreateCompanyRequest): Promise<CrmCompanyRow> {
  return await callModuleApiAuth<CrmCompanyRow>(auth, "crm", "create_company", { ...input });
}

export async function createCompanyTenant(auth: AuthContext, input: CreateCompanyTenantRequest): Promise<CrmCompanyTenantRow> {
  return await callModuleApiAuth<CrmCompanyTenantRow>(auth, "crm", "create_company_tenant", { ...input });
}

export async function createContact(auth: AuthContext, input: CreateContactRequest): Promise<CrmContactRow> {
  return await callModuleApiAuth<CrmContactRow>(auth, "crm", "create_contact", { ...input });
}

export async function createContactCompany(auth: AuthContext, input: CreateContactCompanyRequest): Promise<CrmContactCompanyRow> {
  return await callModuleApiAuth<CrmContactCompanyRow>(auth, "crm", "create_contact_company", { ...input });
}

export async function createContactTenant(auth: AuthContext, input: CreateContactTenantRequest): Promise<CrmContactTenantRow> {
  return await callModuleApiAuth<CrmContactTenantRow>(auth, "crm", "create_contact_tenant", { ...input });
}

export async function createCustomField(auth: AuthContext, input: CreateCustomFieldRequest): Promise<CrmCustomFieldRow> {
  return await callModuleApiAuth<CrmCustomFieldRow>(auth, "crm", "create_custom_field", { ...input });
}

export async function createInteraction(auth: AuthContext, input: CreateInteractionRequest): Promise<CrmInteractionRow> {
  return await callModuleApiAuth<CrmInteractionRow>(auth, "crm", "create_interaction", { ...input });
}

export async function createLead(auth: AuthContext, input: CreateLeadRequest): Promise<CrmLeadRow> {
  return await callModuleApiAuth<CrmLeadRow>(auth, "crm", "create_lead", { ...input });
}

export async function createList(auth: AuthContext, input: CreateListRequest): Promise<CrmListRow> {
  return await callModuleApiAuth<CrmListRow>(auth, "crm", "create_list", { ...input });
}

export async function createListMember(auth: AuthContext, input: CreateListMemberRequest): Promise<CrmListMemberRow> {
  return await callModuleApiAuth<CrmListMemberRow>(auth, "crm", "create_list_member", { ...input });
}

export async function createNote(auth: AuthContext, input: CreateNoteRequest): Promise<CrmNoteRow> {
  return await callModuleApiAuth<CrmNoteRow>(auth, "crm", "create_note", { ...input });
}

export async function createOpportunity(auth: AuthContext, input: CreateOpportunityRequest): Promise<CrmOpportunityRow> {
  return await callModuleApiAuth<CrmOpportunityRow>(auth, "crm", "create_opportunity", { ...input });
}

export async function createPipeline(auth: AuthContext, input: CreatePipelineRequest): Promise<CrmPipelineRow> {
  return await callModuleApiAuth<CrmPipelineRow>(auth, "crm", "create_pipeline", { ...input });
}

export async function createPipelineStage(auth: AuthContext, input: CreatePipelineStageRequest): Promise<CrmPipelineStageRow> {
  return await callModuleApiAuth<CrmPipelineStageRow>(auth, "crm", "create_pipeline_stage", { ...input });
}

export async function createTag(auth: AuthContext, input: CreateTagRequest): Promise<CrmTagRow> {
  return await callModuleApiAuth<CrmTagRow>(auth, "crm", "create_tag", { ...input });
}

export async function createTagAssignment(auth: AuthContext, input: CreateTagAssignmentRequest): Promise<CrmTagAssignmentRow> {
  return await callModuleApiAuth<CrmTagAssignmentRow>(auth, "crm", "create_tag_assignment", { ...input });
}

export async function createTask(auth: AuthContext, input: CreateTaskRequest): Promise<CrmTaskRow> {
  return await callModuleApiAuth<CrmTaskRow>(auth, "crm", "create_task", { ...input });
}

export async function deleteCampaign(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_campaign", { id: id });
}

export async function deleteCompany(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_company", { id: id });
}

export async function deleteCompanyTenant(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_company_tenant", { id: id });
}

export async function deleteContact(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_contact", { id: id });
}

export async function deleteContactCompany(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_contact_company", { id: id });
}

export async function deleteContactTenant(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_contact_tenant", { id: id });
}

export async function deleteCustomField(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_custom_field", { id: id });
}

export async function deleteCustomFieldValue(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_custom_field_value", { id: id });
}

export async function deleteLead(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_lead", { id: id });
}

export async function deleteList(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_list", { id: id });
}

export async function deleteListMember(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_list_member", { id: id });
}

export async function deleteNote(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_note", { id: id });
}

export async function deleteOpportunity(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_opportunity", { id: id });
}

export async function deletePipeline(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_pipeline", { id: id });
}

export async function deletePipelineStage(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_pipeline_stage", { id: id });
}

export async function deleteTag(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_tag", { id: id });
}

export async function deleteTagAssignment(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_tag_assignment", { id: id });
}

export async function deleteTask(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "crm", "delete_task", { id: id });
}

export async function getCampaign(auth: AuthContext, id: string): Promise<CrmCampaignRow> {
  await tid(auth);
  return await callModuleApiAuth<CrmCampaignRow>(auth, "crm", "get_campaign", { id: id });
}

export async function getCompany(auth: AuthContext, id: string): Promise<CrmCompanyRow> {
  await tid(auth);
  return await callModuleApiAuth<CrmCompanyRow>(auth, "crm", "get_company", { id: id });
}

export async function getContact(auth: AuthContext, id: string): Promise<CrmContactRow> {
  await tid(auth);
  return await callModuleApiAuth<CrmContactRow>(auth, "crm", "get_contact", { id: id });
}

export async function getLead(auth: AuthContext, id: string): Promise<CrmLeadRow> {
  await tid(auth);
  return await callModuleApiAuth<CrmLeadRow>(auth, "crm", "get_lead", { id: id });
}

export async function getList(auth: AuthContext, id: string): Promise<CrmListRow> {
  await tid(auth);
  return await callModuleApiAuth<CrmListRow>(auth, "crm", "get_list", { id: id });
}

export async function getOpportunity(auth: AuthContext, id: string): Promise<CrmOpportunityRow> {
  await tid(auth);
  return await callModuleApiAuth<CrmOpportunityRow>(auth, "crm", "get_opportunity", { id: id });
}

export async function getPipeline(auth: AuthContext, id: string): Promise<PipelineDetail> {
  await tid(auth);
  return await callModuleApiAuth<PipelineDetail>(auth, "crm", "get_pipeline", { id: id });
}

export async function getTask(auth: AuthContext, id: string): Promise<CrmTaskRow> {
  await tid(auth);
  return await callModuleApiAuth<CrmTaskRow>(auth, "crm", "get_task", { id: id });
}

export async function listCampaigns(auth: AuthContext, status?: string): Promise<CrmCampaignRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (status !== undefined) payload.status = status;
  return await callModuleApiAuth<CrmCampaignRow[]>(auth, "crm", "list_campaigns", payload);
}

export async function listCompanies(auth: AuthContext): Promise<CrmCompanyRow[]> {
  await tid(auth);
  return await callModuleApiAuth<CrmCompanyRow[]>(auth, "crm", "list_companies");
}

export async function listContactCompanies(auth: AuthContext, contactId?: string, companyId?: string): Promise<CrmContactCompanyRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (contactId !== undefined) payload.contact_id = contactId;
  if (companyId !== undefined) payload.company_id = companyId;
  return await callModuleApiAuth<CrmContactCompanyRow[]>(auth, "crm", "list_contact_companies", payload);
}

export async function listContactTenants(auth: AuthContext, contactId?: string): Promise<CrmContactTenantRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (contactId !== undefined) payload.contact_id = contactId;
  return await callModuleApiAuth<CrmContactTenantRow[]>(auth, "crm", "list_contact_tenants", payload);
}

export async function listContacts(auth: AuthContext, status?: string): Promise<CrmContactRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (status !== undefined) payload.status = status;
  return await callModuleApiAuth<CrmContactRow[]>(auth, "crm", "list_contacts", payload);
}

export async function listCompanyTenants(auth: AuthContext, companyId?: string): Promise<CrmCompanyTenantRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (companyId !== undefined) payload.company_id = companyId;
  return await callModuleApiAuth<CrmCompanyTenantRow[]>(auth, "crm", "list_company_tenants", payload);
}

export async function listCustomFieldValues(auth: AuthContext, entityType?: string, entityId?: string, customFieldId?: string): Promise<CrmCustomFieldValueRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (entityType !== undefined) payload.entity_type = entityType;
  if (entityId !== undefined) payload.entity_id = entityId;
  if (customFieldId !== undefined) payload.custom_field_id = customFieldId;
  return await callModuleApiAuth<CrmCustomFieldValueRow[]>(auth, "crm", "list_custom_field_values", payload);
}

export async function listCustomFields(auth: AuthContext, appliesTo?: string): Promise<CrmCustomFieldRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (appliesTo !== undefined) payload.applies_to = appliesTo;
  return await callModuleApiAuth<CrmCustomFieldRow[]>(auth, "crm", "list_custom_fields", payload);
}

export async function listInteractions(auth: AuthContext, contactId?: string, leadId?: string, opportunityId?: string, companyId?: string, limit?: number): Promise<CrmInteractionRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (contactId !== undefined) payload.contact_id = contactId;
  if (leadId !== undefined) payload.lead_id = leadId;
  if (opportunityId !== undefined) payload.opportunity_id = opportunityId;
  if (companyId !== undefined) payload.company_id = companyId;
  if (limit !== undefined) payload.limit = limit;
  return await callModuleApiAuth<CrmInteractionRow[]>(auth, "crm", "list_interactions", payload);
}

export async function listLeads(auth: AuthContext, status?: string, campaignId?: string): Promise<CrmLeadRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (status !== undefined) payload.status = status;
  if (campaignId !== undefined) payload.campaign_id = campaignId;
  return await callModuleApiAuth<CrmLeadRow[]>(auth, "crm", "list_leads", payload);
}

export async function listListMembers(auth: AuthContext, listId: string): Promise<CrmListMemberRow[]> {
  await tid(auth);
  return await callModuleApiAuth<CrmListMemberRow[]>(auth, "crm", "list_list_members", { list_id: listId });
}

export async function listLists(auth: AuthContext): Promise<CrmListRow[]> {
  await tid(auth);
  return await callModuleApiAuth<CrmListRow[]>(auth, "crm", "list_lists");
}

export async function listNotes(auth: AuthContext, entityType: string, entityId: string): Promise<CrmNoteRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  payload.entity_type = entityType;
  payload.entity_id = entityId;
  return await callModuleApiAuth<CrmNoteRow[]>(auth, "crm", "list_notes", payload);
}

export async function listOpportunities(auth: AuthContext, pipelineId?: string, stageId?: string, status?: string): Promise<CrmOpportunityRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (pipelineId !== undefined) payload.pipeline_id = pipelineId;
  if (stageId !== undefined) payload.stage_id = stageId;
  if (status !== undefined) payload.status = status;
  return await callModuleApiAuth<CrmOpportunityRow[]>(auth, "crm", "list_opportunities", payload);
}

export async function listPipelineStages(auth: AuthContext, pipelineId: string): Promise<CrmPipelineStageRow[]> {
  await tid(auth);
  return await callModuleApiAuth<CrmPipelineStageRow[]>(auth, "crm", "list_pipeline_stages", { pipeline_id: pipelineId });
}

export async function listPipelines(auth: AuthContext): Promise<CrmPipelineRow[]> {
  await tid(auth);
  return await callModuleApiAuth<CrmPipelineRow[]>(auth, "crm", "list_pipelines");
}

export async function listTagAssignments(auth: AuthContext, entityType?: string, entityId?: string): Promise<CrmTagAssignmentRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (entityType !== undefined) payload.entity_type = entityType;
  if (entityId !== undefined) payload.entity_id = entityId;
  return await callModuleApiAuth<CrmTagAssignmentRow[]>(auth, "crm", "list_tag_assignments", payload);
}

export async function listTags(auth: AuthContext): Promise<CrmTagRow[]> {
  await tid(auth);
  return await callModuleApiAuth<CrmTagRow[]>(auth, "crm", "list_tags");
}

export async function listTasks(auth: AuthContext, targetType?: string, targetId?: string, status?: string): Promise<CrmTaskRow[]> {
  await tid(auth);
  const payload: Record<string, unknown> = {};
  if (targetType !== undefined) payload.target_type = targetType;
  if (targetId !== undefined) payload.target_id = targetId;
  if (status !== undefined) payload.status = status;
  return await callModuleApiAuth<CrmTaskRow[]>(auth, "crm", "list_tasks", payload);
}

export async function softDeleteInteraction(auth: AuthContext, id: string): Promise<{ soft_deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth<{ soft_deleted: true; id: string }>(auth, "crm", "soft_delete_interaction", { id: id });
}

export async function updateCampaign(auth: AuthContext, input: UpdateCampaignRequest): Promise<CrmCampaignRow> {
  return await callModuleApiAuth<CrmCampaignRow>(auth, "crm", "update_campaign", { ...input });
}

export async function updateCompany(auth: AuthContext, input: UpdateCompanyRequest): Promise<CrmCompanyRow> {
  return await callModuleApiAuth<CrmCompanyRow>(auth, "crm", "update_company", { ...input });
}

export async function updateCompanyTenant(auth: AuthContext, input: UpdateCompanyTenantRequest): Promise<CrmCompanyTenantRow> {
  return await callModuleApiAuth<CrmCompanyTenantRow>(auth, "crm", "update_company_tenant", { ...input });
}

export async function updateContact(auth: AuthContext, input: UpdateContactRequest): Promise<CrmContactRow> {
  return await callModuleApiAuth<CrmContactRow>(auth, "crm", "update_contact", { ...input });
}

export async function updateContactCompany(auth: AuthContext, input: UpdateContactCompanyRequest): Promise<CrmContactCompanyRow> {
  return await callModuleApiAuth<CrmContactCompanyRow>(auth, "crm", "update_contact_company", { ...input });
}

export async function updateContactTenant(auth: AuthContext, input: UpdateContactTenantRequest): Promise<CrmContactTenantRow> {
  return await callModuleApiAuth<CrmContactTenantRow>(auth, "crm", "update_contact_tenant", { ...input });
}

export async function updateCustomField(auth: AuthContext, input: UpdateCustomFieldRequest): Promise<CrmCustomFieldRow> {
  return await callModuleApiAuth<CrmCustomFieldRow>(auth, "crm", "update_custom_field", { ...input });
}

export async function updateCustomFieldValue(auth: AuthContext, input: UpdateCustomFieldValueRequest): Promise<CrmCustomFieldValueRow> {
  return await callModuleApiAuth<CrmCustomFieldValueRow>(auth, "crm", "update_custom_field_value", { ...input });
}

export async function updateLead(auth: AuthContext, input: UpdateLeadRequest): Promise<CrmLeadRow> {
  return await callModuleApiAuth<CrmLeadRow>(auth, "crm", "update_lead", { ...input });
}

export async function updateList(auth: AuthContext, input: UpdateListRequest): Promise<CrmListRow> {
  return await callModuleApiAuth<CrmListRow>(auth, "crm", "update_list", { ...input });
}

export async function updateNote(auth: AuthContext, input: UpdateNoteRequest): Promise<CrmNoteRow> {
  return await callModuleApiAuth<CrmNoteRow>(auth, "crm", "update_note", { ...input });
}

export async function updateOpportunity(auth: AuthContext, input: UpdateOpportunityRequest): Promise<CrmOpportunityRow> {
  return await callModuleApiAuth<CrmOpportunityRow>(auth, "crm", "update_opportunity", { ...input });
}

export async function updatePipeline(auth: AuthContext, input: UpdatePipelineRequest): Promise<CrmPipelineRow> {
  return await callModuleApiAuth<CrmPipelineRow>(auth, "crm", "update_pipeline", { ...input });
}

export async function updatePipelineStage(auth: AuthContext, input: UpdatePipelineStageRequest): Promise<CrmPipelineStageRow> {
  return await callModuleApiAuth<CrmPipelineStageRow>(auth, "crm", "update_pipeline_stage", { ...input });
}

export async function updateTag(auth: AuthContext, input: UpdateTagRequest): Promise<CrmTagRow> {
  return await callModuleApiAuth<CrmTagRow>(auth, "crm", "update_tag", { ...input });
}

export async function updateTask(auth: AuthContext, input: UpdateTaskRequest): Promise<CrmTaskRow> {
  return await callModuleApiAuth<CrmTaskRow>(auth, "crm", "update_task", { ...input });
}

export async function upsertCustomFieldValue(auth: AuthContext, input: UpsertCustomFieldValueRequest): Promise<CrmCustomFieldValueRow> {
  return await callModuleApiAuth<CrmCustomFieldValueRow>(auth, "crm", "upsert_custom_field_value", { ...input });
}
