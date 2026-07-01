export interface CrmPipelineRow {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  is_default: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmPipelineStageRow {
  id: string;
  tenant_id: string;
  pipeline_id: string;
  name: string;
  stage_order: number;
  probability: number;
  is_terminal: boolean;
  terminal_outcome: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface PipelineDetail {
  pipeline: CrmPipelineRow;
  stages: CrmPipelineStageRow[];
}

export interface CrmCampaignRow {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  campaign_type: string;
  status: string;
  start_date: string | null;
  end_date: string | null;
  budget: number | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmTagRow {
  id: string;
  tenant_id: string;
  name: string;
  color: string | null;
  created_at: string;
  deleted_at: string | null;
}

export interface CrmCompanyRow {
  id: string;
  tenant_id: string;
  name: string;
  legal_name: string | null;
  website: string | null;
  industry: string | null;
  owner_user_id: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmContactRow {
  id: string;
  tenant_id: string;
  first_name: string | null;
  last_name: string | null;
  display_name: string | null;
  email: string | null;
  phone: string | null;
  language: string | null;
  timezone: string | null;
  marketing_consent: boolean;
  marketing_consent_at: string | null;
  gdpr_consent: boolean;
  gdpr_consent_at: string | null;
  status: string;
  lead_source: string | null;
  owner_user_id: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmLeadRow {
  id: string;
  tenant_id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  phone: string | null;
  status: string;
  source: string | null;
  score: number | null;
  temperature: string | null;
  owner_user_id: string | null;
  estimated_value: number | null;
  campaign_id: string | null;
  converted_contact_id: string | null;
  converted_company_id: string | null;
  converted_tenant_id: string | null;
  converted_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmContactCompanyRow {
  id: string;
  tenant_id: string;
  contact_id: string;
  company_id: string;
  role: string;
  is_primary: boolean;
  created_at: string;
  deleted_at: string | null;
}

export interface CrmCompanyTenantRow {
  id: string;
  tenant_id: string;
  company_id: string;
  linked_tenant_id: string | null;
  relationship_type: string | null;
  created_at: string;
  deleted_at: string | null;
}

export interface CrmContactTenantRow {
  id: string;
  tenant_id: string;
  contact_id: string;
  linked_tenant_id: string | null;
  relationship_type: string | null;
  created_at: string;
  deleted_at: string | null;
}

export interface CrmOpportunityRow {
  id: string;
  tenant_id: string;
  pipeline_id: string;
  stage_id: string;
  contact_id: string | null;
  company_id: string | null;
  linked_tenant_id: string | null;
  name: string;
  expected_revenue: number | null;
  probability: number | null;
  expected_close_date: string | null;
  owner_user_id: string | null;
  status: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmTaskRow {
  id: string;
  tenant_id: string;
  title: string;
  description: string | null;
  target_type: string;
  target_id: string;
  priority: string;
  due_at: string | null;
  status: string;
  owner_user_id: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmInteractionRow {
  id: string;
  tenant_id: string;
  interaction_type: string;
  subject: string | null;
  metadata: Record<string, unknown>;
  contact_id: string | null;
  company_id: string | null;
  lead_id: string | null;
  opportunity_id: string | null;
  recorded_by: string | null;
  occurred_at: string;
  created_at: string;
  deleted_at: string | null;
}

export interface CrmNoteRow {
  id: string;
  tenant_id: string;
  entity_type: string;
  entity_id: string;
  body: string;
  version: number;
  author_user_id: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmTagAssignmentRow {
  id: string;
  tenant_id: string;
  tag_id: string;
  entity_type: string;
  entity_id: string;
  created_at: string;
  deleted_at: string | null;
}

export interface CrmListRow {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  list_type: string;
  filter_config: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmListMemberRow {
  id: string;
  tenant_id: string;
  list_id: string;
  contact_id: string;
  added_at: string;
  deleted_at: string | null;
}

export interface CrmCustomFieldRow {
  id: string;
  tenant_id: string;
  field_key: string;
  label: string;
  field_type: string;
  applies_to: string;
  options: Record<string, unknown> | null;
  is_required: boolean;
  display_order: number;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CrmCustomFieldValueRow {
  id: string;
  tenant_id: string;
  custom_field_id: string;
  entity_type: string;
  entity_id: string;
  value_text: string | null;
  value_number: number | null;
  value_boolean: boolean | null;
  value_date: string | null;
  value_datetime: string | null;
  value_json: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
}

export interface CreatePipelineRequest {
  name: string;
  description?: string;
  is_default?: boolean;
  is_active?: boolean;
}

export interface UpdatePipelineRequest {
  id: string;
  name?: string;
  description?: string | null;
  is_default?: boolean;
  is_active?: boolean;
}

export interface CreatePipelineStageRequest {
  pipeline_id: string;
  name: string;
  stage_order: number;
  probability?: number;
  is_terminal?: boolean;
  terminal_outcome?: string;
}

export interface UpdatePipelineStageRequest {
  id: string;
  name?: string;
  stage_order?: number;
  probability?: number;
  is_terminal?: boolean;
  terminal_outcome?: string | null;
}

export interface CreateCampaignRequest {
  name: string;
  description?: string;
  campaign_type?: string;
  status?: string;
  start_date?: string;
  end_date?: string;
  budget?: number;
}

export interface UpdateCampaignRequest {
  id: string;
  name?: string;
  description?: string | null;
  campaign_type?: string;
  status?: string;
  start_date?: string | null;
  end_date?: string | null;
  budget?: number | null;
}

export interface CreateTagRequest {
  name: string;
  color?: string;
}

export interface UpdateTagRequest {
  id: string;
  name?: string;
  color?: string | null;
}

export interface CreateCompanyRequest {
  name: string;
  legal_name?: string;
  website?: string;
  industry?: string;
  owner_user_id?: string;
}

export interface UpdateCompanyRequest {
  id: string;
  name?: string;
  legal_name?: string | null;
  website?: string | null;
  industry?: string | null;
  owner_user_id?: string | null;
}

export interface CreateContactRequest {
  first_name?: string;
  last_name?: string;
  display_name?: string;
  email?: string;
  phone?: string;
  language?: string;
  timezone?: string;
  marketing_consent?: boolean;
  gdpr_consent?: boolean;
  status?: string;
  lead_source?: string;
  owner_user_id?: string;
}

export interface UpdateContactRequest {
  id: string;
  first_name?: string | null;
  last_name?: string | null;
  display_name?: string | null;
  email?: string | null;
  phone?: string | null;
  language?: string | null;
  timezone?: string | null;
  marketing_consent?: boolean;
  gdpr_consent?: boolean;
  status?: string;
  lead_source?: string | null;
  owner_user_id?: string | null;
}

export interface CreateLeadRequest {
  first_name?: string;
  last_name?: string;
  email?: string;
  phone?: string;
  status?: string;
  source?: string;
  score?: number;
  temperature?: string;
  owner_user_id?: string;
  estimated_value?: number;
  campaign_id?: string;
}

export interface UpdateLeadRequest {
  id: string;
  first_name?: string | null;
  last_name?: string | null;
  email?: string | null;
  phone?: string | null;
  status?: string;
  source?: string | null;
  score?: number | null;
  temperature?: string | null;
  owner_user_id?: string | null;
  estimated_value?: number | null;
  campaign_id?: string | null;
  converted_contact_id?: string | null;
  converted_company_id?: string | null;
  converted_tenant_id?: string | null;
}

export interface CreateContactCompanyRequest {
  contact_id: string;
  company_id: string;
  role: string;
  is_primary?: boolean;
}

export interface UpdateContactCompanyRequest {
  id: string;
  role?: string;
  is_primary?: boolean;
}

export interface CreateCompanyTenantRequest {
  company_id: string;
  linked_tenant_id?: string;
  relationship_type?: string;
}

export interface UpdateCompanyTenantRequest {
  id: string;
  linked_tenant_id?: string | null;
  relationship_type?: string | null;
}

export interface CreateContactTenantRequest {
  contact_id: string;
  linked_tenant_id?: string;
  relationship_type?: string;
}

export interface UpdateContactTenantRequest {
  id: string;
  linked_tenant_id?: string | null;
  relationship_type?: string | null;
}

export interface CreateOpportunityRequest {
  pipeline_id: string;
  stage_id: string;
  name: string;
  contact_id?: string;
  company_id?: string;
  linked_tenant_id?: string;
  expected_revenue?: number;
  probability?: number;
  expected_close_date?: string;
  owner_user_id?: string;
  status?: string;
}

export interface UpdateOpportunityRequest {
  id: string;
  pipeline_id?: string;
  stage_id?: string;
  name?: string;
  contact_id?: string | null;
  company_id?: string | null;
  linked_tenant_id?: string | null;
  expected_revenue?: number | null;
  probability?: number | null;
  expected_close_date?: string | null;
  owner_user_id?: string | null;
  status?: string;
}

export interface CreateTaskRequest {
  title: string;
  description?: string;
  target_type: string;
  target_id: string;
  priority?: string;
  due_at?: string;
  status?: string;
  owner_user_id?: string;
}

export interface UpdateTaskRequest {
  id: string;
  title?: string;
  description?: string | null;
  target_type?: string;
  target_id?: string;
  priority?: string;
  due_at?: string | null;
  status?: string;
  owner_user_id?: string | null;
}

export interface CreateInteractionRequest {
  interaction_type: string;
  subject?: string;
  metadata?: Record<string, unknown>;
  contact_id?: string;
  company_id?: string;
  lead_id?: string;
  opportunity_id?: string;
  occurred_at?: string;
}

export interface SoftDeleteInteractionRequest {
  id: string;
}

export interface CreateNoteRequest {
  entity_type: string;
  entity_id: string;
  body: string;
}

export interface UpdateNoteRequest {
  id: string;
  body?: string;
}

export interface CreateTagAssignmentRequest {
  tag_id: string;
  entity_type: string;
  entity_id: string;
}

export interface CreateListRequest {
  name: string;
  description?: string;
  list_type?: string;
  filter_config?: Record<string, unknown>;
}

export interface UpdateListRequest {
  id: string;
  name?: string;
  description?: string | null;
  list_type?: string;
  filter_config?: Record<string, unknown> | null;
}

export interface CreateListMemberRequest {
  list_id: string;
  contact_id: string;
}

export interface CreateCustomFieldRequest {
  field_key: string;
  label: string;
  field_type: string;
  applies_to: string;
  options?: Record<string, unknown>;
  is_required?: boolean;
  display_order?: number;
}

export interface UpdateCustomFieldRequest {
  id: string;
  field_key?: string;
  label?: string;
  field_type?: string;
  applies_to?: string;
  options?: Record<string, unknown> | null;
  is_required?: boolean;
  display_order?: number;
}

export interface UpsertCustomFieldValueRequest {
  custom_field_id: string;
  entity_type: string;
  entity_id: string;
  value_text?: string;
  value_number?: number;
  value_boolean?: boolean;
  value_date?: string;
  value_datetime?: string;
  value_json?: Record<string, unknown>;
}

export interface UpdateCustomFieldValueRequest {
  id: string;
  value_text?: string | null;
  value_number?: number | null;
  value_boolean?: boolean | null;
  value_date?: string | null;
  value_datetime?: string | null;
  value_json?: Record<string, unknown> | null;
}
