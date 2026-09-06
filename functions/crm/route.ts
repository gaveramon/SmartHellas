import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { pipelinesHandler } from "./handlers/pipelines.ts";
import { pipelineHandler } from "./handlers/pipeline.ts";
import { pipelineStagesHandler } from "./handlers/pipeline_stages.ts";
import { pipelineStageHandler } from "./handlers/pipeline_stage.ts";
import { campaignsHandler } from "./handlers/campaigns.ts";
import { campaignHandler } from "./handlers/campaign.ts";
import { tagsHandler } from "./handlers/tags.ts";
import { tagHandler } from "./handlers/tag.ts";
import { companiesHandler } from "./handlers/companies.ts";
import { companyHandler } from "./handlers/company.ts";
import { contactsHandler } from "./handlers/contacts.ts";
import { contactHandler } from "./handlers/contact.ts";
import { leadsHandler } from "./handlers/leads.ts";
import { leadHandler } from "./handlers/lead.ts";
import { contactCompaniesHandler } from "./handlers/contact_companies.ts";
import { contactCompanyHandler } from "./handlers/contact_company.ts";
import { companyTenantsHandler } from "./handlers/company_tenants.ts";
import { companyTenantHandler } from "./handlers/company_tenant.ts";
import { contactTenantsHandler } from "./handlers/contact_tenants.ts";
import { contactTenantHandler } from "./handlers/contact_tenant.ts";
import { opportunitiesHandler } from "./handlers/opportunities.ts";
import { opportunityHandler } from "./handlers/opportunity.ts";
import { tasksHandler } from "./handlers/tasks.ts";
import { taskHandler } from "./handlers/task.ts";
import { interactionsHandler } from "./handlers/interactions.ts";
import { interactionHandler } from "./handlers/interaction.ts";
import { notesHandler } from "./handlers/notes.ts";
import { noteHandler } from "./handlers/note.ts";
import { tagAssignmentsHandler } from "./handlers/tag_assignments.ts";
import { tagAssignmentHandler } from "./handlers/tag_assignment.ts";
import { listsHandler } from "./handlers/lists.ts";
import { listHandler } from "./handlers/list.ts";
import { listMembersHandler } from "./handlers/list_members.ts";
import { listMemberHandler } from "./handlers/list_member.ts";
import { customFieldsHandler } from "./handlers/custom_fields.ts";
import { customFieldHandler } from "./handlers/custom_field.ts";
import { customFieldValuesHandler } from "./handlers/custom_field_values.ts";
import { customFieldValueHandler } from "./handlers/custom_field_value.ts";

export const resolveRoute = createRouteResolver("crm");

export const routeHandlers: RouteHandlerMap = {
  "pipelines": pipelinesHandler,
  "pipeline": pipelineHandler,
  "pipeline-stages": pipelineStagesHandler,
  "pipeline-stage": pipelineStageHandler,
  "campaigns": campaignsHandler,
  "campaign": campaignHandler,
  "tags": tagsHandler,
  "tag": tagHandler,
  "companies": companiesHandler,
  "company": companyHandler,
  "contacts": contactsHandler,
  "contact": contactHandler,
  "leads": leadsHandler,
  "lead": leadHandler,
  "contact-companies": contactCompaniesHandler,
  "contact-company": contactCompanyHandler,
  "company-tenants": companyTenantsHandler,
  "company-tenant": companyTenantHandler,
  "contact-tenants": contactTenantsHandler,
  "contact-tenant": contactTenantHandler,
  "opportunities": opportunitiesHandler,
  "opportunity": opportunityHandler,
  "tasks": tasksHandler,
  "task": taskHandler,
  "interactions": interactionsHandler,
  "interaction": interactionHandler,
  "notes": notesHandler,
  "note": noteHandler,
  "tag-assignments": tagAssignmentsHandler,
  "tag-assignment": tagAssignmentHandler,
  "lists": listsHandler,
  "list": listHandler,
  "list-members": listMembersHandler,
  "list-member": listMemberHandler,
  "custom-fields": customFieldsHandler,
  "custom-field": customFieldHandler,
  "custom-field-values": customFieldValuesHandler,
  "custom-field-value": customFieldValueHandler,
};
