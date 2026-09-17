import { ValidationError } from "../shared/errors.ts";
import {
  optionalEnum,
  optionalEnumQuery,
  requireEnum,
} from "../shared/validation.ts";
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
  SoftDeleteInteractionRequest,
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

export { optionalEnumQuery } from "../shared/validation.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const CRM_CONTACT_STATUSES = ["active", "inactive", "archived", "unqualified"] as const;
export const CRM_LEAD_STATUSES = [
  "new",
  "contacted",
  "qualified",
  "unqualified",
  "converted",
  "lost",
] as const;
export const CRM_LEAD_TEMPERATURES = ["cold", "warm", "hot"] as const;
export const CRM_OPPORTUNITY_STATUSES = ["open", "won", "lost", "abandoned"] as const;
export const CRM_TASK_STATUSES = ["pending", "in_progress", "completed", "cancelled"] as const;
export const CRM_TASK_TARGET_TYPES = ["lead", "opportunity", "contact", "company", "tenant"] as const;
export const CRM_INTERACTION_TYPES = [
  "call",
  "email",
  "meeting",
  "portal",
  "sms",
  "whatsapp",
  "system",
] as const;
export const CRM_ENTITY_TYPES = ["lead", "opportunity", "contact", "company", "tenant"] as const;
export const CRM_LIST_TYPES = ["static", "dynamic"] as const;
export const CRM_CAMPAIGN_TYPES = [
  "google_ads",
  "facebook",
  "referral",
  "partner",
  "email",
  "other",
] as const;
export const CRM_CAMPAIGN_STATUSES = ["draft", "active", "paused", "completed", "cancelled"] as const;
export const CRM_CUSTOM_FIELD_TYPES = [
  "text",
  "number",
  "boolean",
  "date",
  "datetime",
  "select",
  "multiselect",
] as const;
export const CRM_TERMINAL_OUTCOMES = ["won", "lost"] as const;
export const PRIORITY_LEVELS = ["low", "normal", "high", "urgent", "critical"] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("crm");
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

export function parseLimitQuery(req: Request, defaultValue = 100): number {
  const raw = new URL(req.url).searchParams.get("limit");
  if (!raw) return defaultValue;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 1) {
    throw new ValidationError("limit must be a positive number");
  }
  return Math.floor(n);
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

export function parseCreatePipelineBody(body: unknown): CreatePipelineRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreatePipelineRequest = { name: requireStringField(r, "name") };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.is_default !== undefined) result.is_default = r.is_default as boolean;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdatePipelineBody(body: unknown): UpdatePipelineRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePipelineRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.is_default !== undefined) result.is_default = r.is_default as boolean;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreatePipelineStageBody(body: unknown): CreatePipelineStageRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const stageOrder = r.stage_order;
  if (typeof stageOrder !== "number" || stageOrder <= 0) {
    throw new ValidationError("stage_order must be a positive number", { field: "stage_order" });
  }
  const result: CreatePipelineStageRequest = {
    pipeline_id: requireUuidField(r, "pipeline_id"),
    name: requireStringField(r, "name"),
    stage_order: stageOrder,
  };
  if (r.probability !== undefined) result.probability = r.probability as number;
  if (r.is_terminal !== undefined) result.is_terminal = r.is_terminal as boolean;
  if (r.terminal_outcome !== undefined) {
    result.terminal_outcome = requireEnum(r.terminal_outcome, "terminal_outcome", CRM_TERMINAL_OUTCOMES);
  }
  return result;
}

export function parseUpdatePipelineStageBody(body: unknown): UpdatePipelineStageRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdatePipelineStageRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.stage_order !== undefined) result.stage_order = r.stage_order as number;
  if (r.probability !== undefined) result.probability = r.probability as number;
  if (r.is_terminal !== undefined) result.is_terminal = r.is_terminal as boolean;
  if (r.terminal_outcome !== undefined) {
    result.terminal_outcome =
      r.terminal_outcome === null
        ? null
        : requireEnum(r.terminal_outcome, "terminal_outcome", CRM_TERMINAL_OUTCOMES);
  }
  return result;
}

export function parseCreateCampaignBody(body: unknown): CreateCampaignRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateCampaignRequest = { name: requireStringField(r, "name") };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.campaign_type !== undefined) {
    result.campaign_type = requireEnum(r.campaign_type, "campaign_type", CRM_CAMPAIGN_TYPES);
  }
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_CAMPAIGN_STATUSES);
  }
  if (r.start_date !== undefined) result.start_date = String(r.start_date);
  if (r.end_date !== undefined) result.end_date = String(r.end_date);
  if (r.budget !== undefined) result.budget = r.budget as number;
  return result;
}

export function parseUpdateCampaignBody(body: unknown): UpdateCampaignRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateCampaignRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.campaign_type !== undefined) {
    result.campaign_type = requireEnum(r.campaign_type, "campaign_type", CRM_CAMPAIGN_TYPES);
  }
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_CAMPAIGN_STATUSES);
  }
  if (r.start_date !== undefined) {
    result.start_date = r.start_date === null ? null : String(r.start_date);
  }
  if (r.end_date !== undefined) {
    result.end_date = r.end_date === null ? null : String(r.end_date);
  }
  if (r.budget !== undefined) result.budget = r.budget as number | null;
  return result;
}

export function parseCreateTagBody(body: unknown): CreateTagRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateTagRequest = { name: requireStringField(r, "name") };
  if (r.color !== undefined) result.color = String(r.color);
  return result;
}

export function parseUpdateTagBody(body: unknown): UpdateTagRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateTagRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.color !== undefined) result.color = r.color as string | null;
  return result;
}

export function parseCreateCompanyBody(body: unknown): CreateCompanyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateCompanyRequest = { name: requireStringField(r, "name") };
  if (r.legal_name !== undefined) result.legal_name = String(r.legal_name);
  if (r.website !== undefined) result.website = String(r.website);
  if (r.industry !== undefined) result.industry = String(r.industry);
  if (r.owner_user_id !== undefined) result.owner_user_id = requireUuidField(r, "owner_user_id");
  return result;
}

export function parseUpdateCompanyBody(body: unknown): UpdateCompanyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateCompanyRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.legal_name !== undefined) result.legal_name = r.legal_name as string | null;
  if (r.website !== undefined) result.website = r.website as string | null;
  if (r.industry !== undefined) result.industry = r.industry as string | null;
  if (r.owner_user_id !== undefined) {
    result.owner_user_id =
      r.owner_user_id === null ? null : requireUuidField(r, "owner_user_id");
  }
  return result;
}

export function parseCreateContactBody(body: unknown): CreateContactRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateContactRequest = {};
  if (r.first_name !== undefined) result.first_name = String(r.first_name);
  if (r.last_name !== undefined) result.last_name = String(r.last_name);
  if (r.display_name !== undefined) result.display_name = String(r.display_name);
  if (r.email !== undefined) result.email = String(r.email);
  if (r.phone !== undefined) result.phone = String(r.phone);
  if (r.language !== undefined) result.language = String(r.language);
  if (r.timezone !== undefined) result.timezone = String(r.timezone);
  if (r.marketing_consent !== undefined) result.marketing_consent = r.marketing_consent as boolean;
  if (r.gdpr_consent !== undefined) result.gdpr_consent = r.gdpr_consent as boolean;
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_CONTACT_STATUSES);
  }
  if (r.lead_source !== undefined) result.lead_source = String(r.lead_source);
  if (r.owner_user_id !== undefined) result.owner_user_id = requireUuidField(r, "owner_user_id");
  return result;
}

export function parseUpdateContactBody(body: unknown): UpdateContactRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateContactRequest = { id: requireUuidField(r, "id") };
  if (r.first_name !== undefined) result.first_name = r.first_name as string | null;
  if (r.last_name !== undefined) result.last_name = r.last_name as string | null;
  if (r.display_name !== undefined) result.display_name = r.display_name as string | null;
  if (r.email !== undefined) result.email = r.email as string | null;
  if (r.phone !== undefined) result.phone = r.phone as string | null;
  if (r.language !== undefined) result.language = r.language as string | null;
  if (r.timezone !== undefined) result.timezone = r.timezone as string | null;
  if (r.marketing_consent !== undefined) result.marketing_consent = r.marketing_consent as boolean;
  if (r.gdpr_consent !== undefined) result.gdpr_consent = r.gdpr_consent as boolean;
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_CONTACT_STATUSES);
  }
  if (r.lead_source !== undefined) result.lead_source = r.lead_source as string | null;
  if (r.owner_user_id !== undefined) {
    result.owner_user_id =
      r.owner_user_id === null ? null : requireUuidField(r, "owner_user_id");
  }
  return result;
}

export function parseCreateLeadBody(body: unknown): CreateLeadRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateLeadRequest = {};
  if (r.first_name !== undefined) result.first_name = String(r.first_name);
  if (r.last_name !== undefined) result.last_name = String(r.last_name);
  if (r.email !== undefined) result.email = String(r.email);
  if (r.phone !== undefined) result.phone = String(r.phone);
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_LEAD_STATUSES);
  }
  if (r.source !== undefined) result.source = String(r.source);
  if (r.score !== undefined) result.score = r.score as number;
  if (r.temperature !== undefined) {
    result.temperature = requireEnum(r.temperature, "temperature", CRM_LEAD_TEMPERATURES);
  }
  if (r.owner_user_id !== undefined) result.owner_user_id = requireUuidField(r, "owner_user_id");
  if (r.estimated_value !== undefined) result.estimated_value = r.estimated_value as number;
  if (r.campaign_id !== undefined) result.campaign_id = requireUuidField(r, "campaign_id");
  return result;
}

export function parseUpdateLeadBody(body: unknown): UpdateLeadRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateLeadRequest = { id: requireUuidField(r, "id") };
  if (r.first_name !== undefined) result.first_name = r.first_name as string | null;
  if (r.last_name !== undefined) result.last_name = r.last_name as string | null;
  if (r.email !== undefined) result.email = r.email as string | null;
  if (r.phone !== undefined) result.phone = r.phone as string | null;
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_LEAD_STATUSES);
  }
  if (r.source !== undefined) result.source = r.source as string | null;
  if (r.score !== undefined) result.score = r.score as number | null;
  if (r.temperature !== undefined) {
    result.temperature =
      r.temperature === null
        ? null
        : requireEnum(r.temperature, "temperature", CRM_LEAD_TEMPERATURES);
  }
  if (r.owner_user_id !== undefined) {
    result.owner_user_id =
      r.owner_user_id === null ? null : requireUuidField(r, "owner_user_id");
  }
  if (r.estimated_value !== undefined) result.estimated_value = r.estimated_value as number | null;
  if (r.campaign_id !== undefined) {
    result.campaign_id =
      r.campaign_id === null ? null : requireUuidField(r, "campaign_id");
  }
  if (r.converted_contact_id !== undefined) {
    result.converted_contact_id =
      r.converted_contact_id === null ? null : requireUuidField(r, "converted_contact_id");
  }
  if (r.converted_company_id !== undefined) {
    result.converted_company_id =
      r.converted_company_id === null ? null : requireUuidField(r, "converted_company_id");
  }
  if (r.converted_tenant_id !== undefined) {
    result.converted_tenant_id =
      r.converted_tenant_id === null ? null : requireUuidField(r, "converted_tenant_id");
  }
  return result;
}

export function parseCreateContactCompanyBody(body: unknown): CreateContactCompanyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateContactCompanyRequest = {
    contact_id: requireUuidField(r, "contact_id"),
    company_id: requireUuidField(r, "company_id"),
    role: requireStringField(r, "role"),
  };
  if (r.is_primary !== undefined) result.is_primary = r.is_primary as boolean;
  return result;
}

export function parseUpdateContactCompanyBody(body: unknown): UpdateContactCompanyRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateContactCompanyRequest = { id: requireUuidField(r, "id") };
  if (r.role !== undefined) result.role = String(r.role);
  if (r.is_primary !== undefined) result.is_primary = r.is_primary as boolean;
  return result;
}

export function parseCreateCompanyTenantBody(body: unknown): CreateCompanyTenantRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateCompanyTenantRequest = {
    company_id: requireUuidField(r, "company_id"),
  };
  if (r.linked_tenant_id !== undefined) {
    result.linked_tenant_id = requireUuidField(r, "linked_tenant_id");
  }
  if (r.relationship_type !== undefined) result.relationship_type = String(r.relationship_type);
  return result;
}

export function parseUpdateCompanyTenantBody(body: unknown): UpdateCompanyTenantRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateCompanyTenantRequest = { id: requireUuidField(r, "id") };
  if (r.linked_tenant_id !== undefined) {
    result.linked_tenant_id =
      r.linked_tenant_id === null ? null : requireUuidField(r, "linked_tenant_id");
  }
  if (r.relationship_type !== undefined) {
    result.relationship_type = r.relationship_type as string | null;
  }
  return result;
}

export function parseCreateContactTenantBody(body: unknown): CreateContactTenantRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateContactTenantRequest = {
    contact_id: requireUuidField(r, "contact_id"),
  };
  if (r.linked_tenant_id !== undefined) {
    result.linked_tenant_id = requireUuidField(r, "linked_tenant_id");
  }
  if (r.relationship_type !== undefined) result.relationship_type = String(r.relationship_type);
  return result;
}

export function parseUpdateContactTenantBody(body: unknown): UpdateContactTenantRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateContactTenantRequest = { id: requireUuidField(r, "id") };
  if (r.linked_tenant_id !== undefined) {
    result.linked_tenant_id =
      r.linked_tenant_id === null ? null : requireUuidField(r, "linked_tenant_id");
  }
  if (r.relationship_type !== undefined) {
    result.relationship_type = r.relationship_type as string | null;
  }
  return result;
}

export function parseCreateOpportunityBody(body: unknown): CreateOpportunityRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateOpportunityRequest = {
    pipeline_id: requireUuidField(r, "pipeline_id"),
    stage_id: requireUuidField(r, "stage_id"),
    name: requireStringField(r, "name"),
  };
  if (r.contact_id !== undefined) result.contact_id = requireUuidField(r, "contact_id");
  if (r.company_id !== undefined) result.company_id = requireUuidField(r, "company_id");
  if (r.linked_tenant_id !== undefined) {
    result.linked_tenant_id = requireUuidField(r, "linked_tenant_id");
  }
  if (r.expected_revenue !== undefined) result.expected_revenue = r.expected_revenue as number;
  if (r.probability !== undefined) result.probability = r.probability as number;
  if (r.expected_close_date !== undefined) {
    result.expected_close_date = String(r.expected_close_date);
  }
  if (r.owner_user_id !== undefined) result.owner_user_id = requireUuidField(r, "owner_user_id");
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_OPPORTUNITY_STATUSES);
  }
  return result;
}

export function parseUpdateOpportunityBody(body: unknown): UpdateOpportunityRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateOpportunityRequest = { id: requireUuidField(r, "id") };
  if (r.pipeline_id !== undefined) result.pipeline_id = requireUuidField(r, "pipeline_id");
  if (r.stage_id !== undefined) result.stage_id = requireUuidField(r, "stage_id");
  if (r.name !== undefined) result.name = String(r.name);
  if (r.contact_id !== undefined) {
    result.contact_id = r.contact_id === null ? null : requireUuidField(r, "contact_id");
  }
  if (r.company_id !== undefined) {
    result.company_id = r.company_id === null ? null : requireUuidField(r, "company_id");
  }
  if (r.linked_tenant_id !== undefined) {
    result.linked_tenant_id =
      r.linked_tenant_id === null ? null : requireUuidField(r, "linked_tenant_id");
  }
  if (r.expected_revenue !== undefined) {
    result.expected_revenue = r.expected_revenue as number | null;
  }
  if (r.probability !== undefined) result.probability = r.probability as number | null;
  if (r.expected_close_date !== undefined) {
    result.expected_close_date =
      r.expected_close_date === null ? null : String(r.expected_close_date);
  }
  if (r.owner_user_id !== undefined) {
    result.owner_user_id =
      r.owner_user_id === null ? null : requireUuidField(r, "owner_user_id");
  }
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_OPPORTUNITY_STATUSES);
  }
  return result;
}

export function parseCreateTaskBody(body: unknown): CreateTaskRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateTaskRequest = {
    title: requireStringField(r, "title"),
    target_type: requireEnum(r.target_type, "target_type", CRM_TASK_TARGET_TYPES),
    target_id: requireUuidField(r, "target_id"),
  };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.priority !== undefined) {
    result.priority = requireEnum(r.priority, "priority", PRIORITY_LEVELS);
  }
  if (r.due_at !== undefined) result.due_at = String(r.due_at);
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_TASK_STATUSES);
  }
  if (r.owner_user_id !== undefined) result.owner_user_id = requireUuidField(r, "owner_user_id");
  return result;
}

export function parseUpdateTaskBody(body: unknown): UpdateTaskRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateTaskRequest = { id: requireUuidField(r, "id") };
  if (r.title !== undefined) result.title = String(r.title);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.target_type !== undefined) {
    result.target_type = requireEnum(r.target_type, "target_type", CRM_TASK_TARGET_TYPES);
  }
  if (r.target_id !== undefined) result.target_id = requireUuidField(r, "target_id");
  if (r.priority !== undefined) {
    result.priority = requireEnum(r.priority, "priority", PRIORITY_LEVELS);
  }
  if (r.due_at !== undefined) result.due_at = r.due_at === null ? null : String(r.due_at);
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", CRM_TASK_STATUSES);
  }
  if (r.owner_user_id !== undefined) {
    result.owner_user_id =
      r.owner_user_id === null ? null : requireUuidField(r, "owner_user_id");
  }
  return result;
}

export function parseCreateInteractionBody(body: unknown): CreateInteractionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateInteractionRequest = {
    interaction_type: requireEnum(r.interaction_type, "interaction_type", CRM_INTERACTION_TYPES),
  };
  if (r.subject !== undefined) result.subject = String(r.subject);
  if (r.metadata !== undefined) result.metadata = requireJsonObject(r.metadata, "metadata");
  if (r.contact_id !== undefined) result.contact_id = requireUuidField(r, "contact_id");
  if (r.company_id !== undefined) result.company_id = requireUuidField(r, "company_id");
  if (r.lead_id !== undefined) result.lead_id = requireUuidField(r, "lead_id");
  if (r.opportunity_id !== undefined) {
    result.opportunity_id = requireUuidField(r, "opportunity_id");
  }
  if (r.occurred_at !== undefined) result.occurred_at = String(r.occurred_at);
  return result;
}

export function parseSoftDeleteInteractionBody(body: unknown): SoftDeleteInteractionRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  return { id: requireUuidField(body as Record<string, unknown>, "id") };
}

export function parseCreateNoteBody(body: unknown): CreateNoteRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  return {
    entity_type: requireEnum(r.entity_type, "entity_type", CRM_ENTITY_TYPES),
    entity_id: requireUuidField(r, "entity_id"),
    body: requireStringField(r, "body"),
  };
}

export function parseUpdateNoteBody(body: unknown): UpdateNoteRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateNoteRequest = { id: requireUuidField(r, "id") };
  if (r.body !== undefined) result.body = requireStringField(r, "body");
  return result;
}

export function parseCreateTagAssignmentBody(body: unknown): CreateTagAssignmentRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  return {
    tag_id: requireUuidField(r, "tag_id"),
    entity_type: requireEnum(r.entity_type, "entity_type", CRM_ENTITY_TYPES),
    entity_id: requireUuidField(r, "entity_id"),
  };
}

export function parseCreateListBody(body: unknown): CreateListRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateListRequest = { name: requireStringField(r, "name") };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.list_type !== undefined) {
    result.list_type = requireEnum(r.list_type, "list_type", CRM_LIST_TYPES);
  }
  if (r.filter_config !== undefined) {
    result.filter_config = requireJsonObject(r.filter_config, "filter_config");
  }
  return result;
}

export function parseUpdateListBody(body: unknown): UpdateListRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateListRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.list_type !== undefined) {
    result.list_type = requireEnum(r.list_type, "list_type", CRM_LIST_TYPES);
  }
  if (r.filter_config !== undefined) {
    result.filter_config =
      r.filter_config === null ? null : requireJsonObject(r.filter_config, "filter_config");
  }
  return result;
}

export function parseCreateListMemberBody(body: unknown): CreateListMemberRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  return {
    list_id: requireUuidField(r, "list_id"),
    contact_id: requireUuidField(r, "contact_id"),
  };
}

export function parseCreateCustomFieldBody(body: unknown): CreateCustomFieldRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateCustomFieldRequest = {
    field_key: requireStringField(r, "field_key"),
    label: requireStringField(r, "label"),
    field_type: requireEnum(r.field_type, "field_type", CRM_CUSTOM_FIELD_TYPES),
    applies_to: requireEnum(r.applies_to, "applies_to", CRM_ENTITY_TYPES),
  };
  if (r.options !== undefined) result.options = requireJsonObject(r.options, "options");
  if (r.is_required !== undefined) result.is_required = r.is_required as boolean;
  if (r.display_order !== undefined) result.display_order = r.display_order as number;
  return result;
}

export function parseUpdateCustomFieldBody(body: unknown): UpdateCustomFieldRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateCustomFieldRequest = { id: requireUuidField(r, "id") };
  if (r.field_key !== undefined) result.field_key = String(r.field_key);
  if (r.label !== undefined) result.label = String(r.label);
  if (r.field_type !== undefined) {
    result.field_type = requireEnum(r.field_type, "field_type", CRM_CUSTOM_FIELD_TYPES);
  }
  if (r.applies_to !== undefined) {
    result.applies_to = requireEnum(r.applies_to, "applies_to", CRM_ENTITY_TYPES);
  }
  if (r.options !== undefined) {
    result.options = r.options === null ? null : requireJsonObject(r.options, "options");
  }
  if (r.is_required !== undefined) result.is_required = r.is_required as boolean;
  if (r.display_order !== undefined) result.display_order = r.display_order as number;
  return result;
}

export function parseUpsertCustomFieldValueBody(body: unknown): UpsertCustomFieldValueRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpsertCustomFieldValueRequest = {
    custom_field_id: requireUuidField(r, "custom_field_id"),
    entity_type: requireEnum(r.entity_type, "entity_type", CRM_ENTITY_TYPES),
    entity_id: requireUuidField(r, "entity_id"),
  };
  if (r.value_text !== undefined) result.value_text = String(r.value_text);
  if (r.value_number !== undefined) result.value_number = r.value_number as number;
  if (r.value_boolean !== undefined) result.value_boolean = r.value_boolean as boolean;
  if (r.value_date !== undefined) result.value_date = String(r.value_date);
  if (r.value_datetime !== undefined) result.value_datetime = String(r.value_datetime);
  if (r.value_json !== undefined) result.value_json = requireJsonObject(r.value_json, "value_json");
  return result;
}

export function parseUpdateCustomFieldValueBody(body: unknown): UpdateCustomFieldValueRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateCustomFieldValueRequest = { id: requireUuidField(r, "id") };
  if (r.value_text !== undefined) result.value_text = r.value_text as string | null;
  if (r.value_number !== undefined) result.value_number = r.value_number as number | null;
  if (r.value_boolean !== undefined) result.value_boolean = r.value_boolean as boolean | null;
  if (r.value_date !== undefined) result.value_date = r.value_date as string | null;
  if (r.value_datetime !== undefined) result.value_datetime = r.value_datetime as string | null;
  if (r.value_json !== undefined) {
    result.value_json =
      r.value_json === null ? null : requireJsonObject(r.value_json, "value_json");
  }
  return result;
}
