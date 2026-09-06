import fs from "node:fs";
import path from "node:path";

const root = path.join(import.meta.dirname, "..");

/** @type {Record<string, Record<string, { op?: string; params?: Array<{ name: string; optional?: boolean; type: string }>; returnType: string }>>} */
const DEFS = {
  optimization: {
    listOptimizationRules: { op: "list_rules", returnType: "OptimizationRuleRow[]" },
    getOptimizationRule: { op: "get_rule", params: [{ name: "id", type: "string" }], returnType: "OptimizationRuleRow" },
    createOptimizationRule: {
      op: "create_rule",
      params: [{ name: "input", type: "CreateOptimizationRuleRequest" }],
      returnType: "OptimizationRuleRow",
    },
    updateOptimizationRule: {
      params: [{ name: "input", type: "UpdateOptimizationRuleRequest" }],
      op: "update_rule",
      returnType: "OptimizationRuleRow",
    },
    deleteOptimizationRule: { op: "delete_rule", params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listInsightEvents: {
      params: [
        { name: "propertyId", optional: true, type: "string" },
        { name: "insightType", optional: true, type: "string" },
      ],
      returnType: "InsightEventRow[]",
    },
    getInsightEvent: { params: [{ name: "id", type: "string" }], returnType: "InsightEventRow" },
    listRecommendations: {
      params: [
        { name: "status", optional: true, type: "string" },
        { name: "propertyId", optional: true, type: "string" },
      ],
      returnType: "OptimizationRecommendationRow[]",
    },
    getRecommendation: { params: [{ name: "id", type: "string" }], returnType: "OptimizationRecommendationRow" },
    updateRecommendation: {
      params: [{ name: "input", type: "UpdateRecommendationRequest" }],
      returnType: "OptimizationRecommendationRow",
    },
    deleteRecommendation: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listDeviceUsageScores: { params: [{ name: "deviceId", optional: true, type: "string" }], returnType: "DeviceUsageScoreRow[]" },
    listEnergyProfiles: { params: [{ name: "propertyId", optional: true, type: "string" }], returnType: "EnergyProfileRow[]" },
    getEnergyProfile: { params: [{ name: "id", type: "string" }], returnType: "EnergyProfileRow" },
  },
  monetization: {
    listProposals: {
      params: [
        { name: "status", optional: true, type: "string" },
        { name: "propertyId", optional: true, type: "string" },
      ],
      returnType: "CustomerProposalRow[]",
    },
    getProposal: { params: [{ name: "id", type: "string" }], returnType: "ProposalDetail" },
    createProposal: { params: [{ name: "input", type: "CreateProposalRequest" }], returnType: "CustomerProposalRow" },
    updateProposal: { params: [{ name: "input", type: "UpdateProposalRequest" }], returnType: "CustomerProposalRow" },
    deleteProposal: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listProposalItems: { params: [{ name: "proposalId", type: "string" }], returnType: "ProposalItemRow[]" },
    createProposalItem: { params: [{ name: "input", type: "CreateProposalItemRequest" }], returnType: "ProposalItemRow" },
    updateProposalItem: { params: [{ name: "input", type: "UpdateProposalItemRequest" }], returnType: "ProposalItemRow" },
    deleteProposalItem: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listPackages: { params: [{ name: "activeOnly", optional: true, type: "boolean" }], returnType: "MonetizationPackageRow[]" },
    getPackage: { params: [{ name: "id", type: "string" }], returnType: "MonetizationPackageRow" },
    createPackage: { params: [{ name: "input", type: "CreatePackageRequest" }], returnType: "MonetizationPackageRow" },
    updatePackage: { params: [{ name: "input", type: "UpdatePackageRequest" }], returnType: "MonetizationPackageRow" },
    deletePackage: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listUpsellCampaigns: {
      params: [
        { name: "triggerEvent", optional: true, type: "string" },
        { name: "activeOnly", optional: true, type: "boolean" },
      ],
      returnType: "UpsellCampaignRow[]",
    },
    getUpsellCampaign: { params: [{ name: "id", type: "string" }], returnType: "UpsellCampaignRow" },
    createUpsellCampaign: { params: [{ name: "input", type: "CreateUpsellCampaignRequest" }], returnType: "UpsellCampaignRow" },
    updateUpsellCampaign: { params: [{ name: "input", type: "UpdateUpsellCampaignRequest" }], returnType: "UpsellCampaignRow" },
    deleteUpsellCampaign: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listActivationState: {
      params: [
        { name: "propertyId", optional: true, type: "string" },
        { name: "serviceType", optional: true, type: "string" },
      ],
      returnType: "ServiceActivationStateRow[]",
    },
    listConversionEvents: {
      params: [
        { name: "proposalId", optional: true, type: "string" },
        { name: "eventType", optional: true, type: "string" },
        { name: "limit", optional: true, type: "number" },
      ],
      returnType: "ConversionEventRow[]",
    },
    listConversionScores: {
      params: [
        { name: "propertyId", optional: true, type: "string" },
        { name: "limit", optional: true, type: "number" },
      ],
      returnType: "ConversionScoreRow[]",
    },
  },
  operations: {
    listTemplates: { returnType: "OperationTemplateRow[]" },
    getTemplate: { params: [{ name: "id", type: "string" }], returnType: "OperationTemplateRow" },
    createTemplate: { params: [{ name: "input", type: "CreateTemplateRequest" }], returnType: "OperationTemplateRow" },
    updateTemplate: { params: [{ name: "input", type: "UpdateTemplateRequest" }], returnType: "OperationTemplateRow" },
    deleteTemplate: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listWorkflows: { returnType: "OperationWorkflowRow[]" },
    getWorkflow: { params: [{ name: "id", type: "string" }], returnType: "WorkflowDetail" },
    createWorkflow: { params: [{ name: "input", type: "CreateWorkflowRequest" }], returnType: "OperationWorkflowRow" },
    updateWorkflow: { params: [{ name: "input", type: "UpdateWorkflowRequest" }], returnType: "OperationWorkflowRow" },
    deleteWorkflow: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listWorkflowSteps: { params: [{ name: "workflowId", type: "string" }], returnType: "WorkflowStepRow[]" },
    createWorkflowStep: { params: [{ name: "input", type: "CreateWorkflowStepRequest" }], returnType: "WorkflowStepRow" },
    updateWorkflowStep: { params: [{ name: "input", type: "UpdateWorkflowStepRequest" }], returnType: "WorkflowStepRow" },
    deleteWorkflowStep: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listWorkflowTriggers: { params: [{ name: "workflowId", type: "string" }], returnType: "WorkflowTriggerRow[]" },
    createWorkflowTrigger: { params: [{ name: "input", type: "CreateWorkflowTriggerRequest" }], returnType: "WorkflowTriggerRow" },
    updateWorkflowTrigger: { params: [{ name: "input", type: "UpdateWorkflowTriggerRequest" }], returnType: "WorkflowTriggerRow" },
    deleteWorkflowTrigger: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listSupportTickets: {
      params: [
        { name: "status", optional: true, type: "string" },
        { name: "priority", optional: true, type: "string" },
      ],
      returnType: "SupportTicketRow[]",
    },
    getSupportTicket: { params: [{ name: "id", type: "string" }], returnType: "SupportTicketRow" },
    createSupportTicket: { params: [{ name: "input", type: "CreateSupportTicketRequest" }], returnType: "SupportTicketRow" },
    updateSupportTicket: { params: [{ name: "input", type: "UpdateSupportTicketRequest" }], returnType: "SupportTicketRow" },
    deleteSupportTicket: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listSupportMessages: { params: [{ name: "ticketId", type: "string" }], returnType: "SupportMessageRow[]" },
    createSupportMessage: { params: [{ name: "input", type: "CreateSupportMessageRequest" }], returnType: "SupportMessageRow" },
  },
  preconfig: {
    listDeviceBundles: {
      params: [
        { name: "propertyType", optional: true, type: "string" },
        { name: "activeOnly", optional: true, type: "boolean" },
      ],
      returnType: "DeviceBundleRow[]",
    },
    getDeviceBundleById: { op: "get_device_bundle", params: [{ name: "id", type: "string" }], returnType: "DeviceBundleRow" },
    getDeviceBundleByCode: {
      op: "get_device_bundle",
      params: [
        { name: "code", type: "string" },
        { name: "version", optional: true, type: "number" },
      ],
      returnType: "DeviceBundleRow",
    },
    createDeviceBundle: { params: [{ name: "input", type: "CreateDeviceBundleRequest" }], returnType: "DeviceBundleRow" },
    updateDeviceBundle: { params: [{ name: "input", type: "UpdateDeviceBundleRequest" }], returnType: "DeviceBundleRow" },
    deleteDeviceBundle: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listBundleDevices: { params: [{ name: "bundleId", type: "string" }], returnType: "BundleDeviceRow[]" },
    createBundleDevice: { params: [{ name: "input", type: "CreateBundleDeviceRequest" }], returnType: "BundleDeviceRow" },
    updateBundleDevice: { params: [{ name: "input", type: "UpdateBundleDeviceRequest" }], returnType: "BundleDeviceRow" },
    deleteBundleDevice: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listOnboardingBlueprints: {
      params: [
        { name: "propertyType", optional: true, type: "string" },
        { name: "activeOnly", optional: true, type: "boolean" },
      ],
      returnType: "OnboardingBlueprintRow[]",
    },
    getOnboardingBlueprintById: { op: "get_onboarding_blueprint", params: [{ name: "id", type: "string" }], returnType: "BlueprintDetail" },
    getOnboardingBlueprintByCode: { op: "get_onboarding_blueprint", params: [{ name: "code", type: "string" }], returnType: "BlueprintDetail" },
    createOnboardingBlueprint: { params: [{ name: "input", type: "CreateBlueprintRequest" }], returnType: "OnboardingBlueprintRow" },
    updateOnboardingBlueprint: { params: [{ name: "input", type: "UpdateBlueprintRequest" }], returnType: "OnboardingBlueprintRow" },
    deleteOnboardingBlueprint: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listBlueprintSteps: { params: [{ name: "blueprintId", type: "string" }], returnType: "OnboardingBlueprintStepRow[]" },
    createBlueprintStep: { params: [{ name: "input", type: "CreateBlueprintStepRequest" }], returnType: "OnboardingBlueprintStepRow" },
    updateBlueprintStep: { params: [{ name: "input", type: "UpdateBlueprintStepRequest" }], returnType: "OnboardingBlueprintStepRow" },
    deleteBlueprintStep: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listPreconfigTemplates: {
      params: [
        { name: "propertyType", optional: true, type: "string" },
        { name: "activeOnly", optional: true, type: "boolean" },
      ],
      returnType: "PreconfigTemplateRow[]",
    },
    getPreconfigTemplate: { params: [{ name: "id", type: "string" }], returnType: "PreconfigTemplateDetail" },
    createPreconfigTemplate: { params: [{ name: "input", type: "CreatePreconfigTemplateRequest" }], returnType: "PreconfigTemplateRow" },
    updatePreconfigTemplate: { params: [{ name: "input", type: "UpdatePreconfigTemplateRequest" }], returnType: "PreconfigTemplateRow" },
    deletePreconfigTemplate: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
    listPreconfigDeviceMap: { params: [{ name: "templateId", type: "string" }], returnType: "PreconfigDeviceMapRow[]" },
    createPreconfigDeviceMap: { params: [{ name: "input", type: "CreatePreconfigDeviceMapRequest" }], returnType: "PreconfigDeviceMapRow" },
    updatePreconfigDeviceMap: { params: [{ name: "input", type: "UpdatePreconfigDeviceMapRequest" }], returnType: "PreconfigDeviceMapRow" },
    deletePreconfigDeviceMap: { params: [{ name: "id", type: "string" }], returnType: "{ deleted: true; id: string }" },
  },
};

function camelToSnake(name) {
  return name.replace(/([A-Z])/g, "_$1").toLowerCase().replace(/^_/, "");
}

function paramToPayloadKey(name) {
  return camelToSnake(name);
}

function defaultOp(fnName) {
  return camelToSnake(fnName);
}

function extractFnNames(indexPath) {
  const text = fs.readFileSync(indexPath, "utf8");
  const marker = 'from "./service.ts"';
  const idx = text.indexOf(marker);
  if (idx < 0) return [];
  const before = text.slice(0, idx);
  const importStart = before.lastIndexOf("import");
  const block = before.slice(importStart);
  const m = block.match(/\{([\s\S]*)\}\s*$/);
  if (!m) return [];
  return m[1]
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s && !s.startsWith("type "));
}

function collectTypes(moduleDefs, typesText) {
  const exported = new Set();
  for (const m of typesText.matchAll(/^export (?:type|interface) (\w+)/gm)) exported.add(m[1]);
  const used = new Set();
  for (const def of Object.values(moduleDefs)) {
    for (const t of [def.returnType, ...(def.params ?? []).map((p) => p.type)]) {
      if (exported.has(t)) used.add(t);
      const arr = t.match(/^(\w+)\[\]$/);
      if (arr && exported.has(arr[1])) used.add(arr[1]);
      const obj = t.match(/^\{ .+\}$/);
      if (obj) continue;
    }
  }
  return [...used].sort();
}

function buildFn(module, fnName, def) {
  const op = def.op ?? defaultOp(fnName);
  const params = def.params ?? [];
  const lines = [`export async function ${fnName}(auth: AuthContext`];
  for (const p of params) {
    lines[0] += `, ${p.name}${p.optional ? "?" : ""}: ${p.type}`;
  }
  lines[0] += `): Promise<${def.returnType}> {`;

  const inputParam = params.find((p) => p.name === "input");
  if (params.length === 0) {
    lines.push("  tid(auth);");
    lines.push(`  return await callModuleApiAuth<${def.returnType}>(auth, "${module}", "${op}");`);
  } else if (params.length === 1 && inputParam) {
    lines.push(`  return await callModuleApiAuth<${def.returnType}>(auth, "${module}", "${op}", { ...input });`);
  } else if (params.length === 1 && !inputParam) {
    const key = paramToPayloadKey(params[0].name);
    lines.push("  tid(auth);");
    if (params[0].optional) {
      lines.push("  const payload: Record<string, unknown> = {};");
      lines.push(`  if (${params[0].name} !== undefined) payload.${key} = ${params[0].name};`);
      lines.push(`  return await callModuleApiAuth<${def.returnType}>(auth, "${module}", "${op}", payload);`);
    } else {
      lines.push(
        `  return await callModuleApiAuth<${def.returnType}>(auth, "${module}", "${op}", { ${key}: ${params[0].name} });`,
      );
    }
  } else {
    lines.push("  tid(auth);");
    if (inputParam) {
      lines.push("  const payload: Record<string, unknown> = { ...input };");
      for (const p of params.filter((x) => x.name !== "input")) {
        const key = paramToPayloadKey(p.name);
        if (p.optional) lines.push(`  if (${p.name} !== undefined) payload.${key} = ${p.name};`);
        else lines.push(`  payload.${key} = ${p.name};`);
      }
    } else {
      lines.push("  const payload: Record<string, unknown> = {};");
      for (const p of params) {
        const key = paramToPayloadKey(p.name);
        if (p.optional) lines.push(`  if (${p.name} !== undefined) payload.${key} = ${p.name};`);
        else lines.push(`  payload.${key} = ${p.name};`);
      }
    }
    lines.push(`  return await callModuleApiAuth<${def.returnType}>(auth, "${module}", "${op}", payload);`);
  }
  lines.push("}");
  return lines.join("\n");
}

function crmDefs() {
  const deleteReturn = "{ deleted: true; id: string }";
  const softDeleteReturn = "{ soft_deleted: true; id: string }";
  const cr = (name, returnType, params = []) => ({ params, returnType });
  const del = (name) => cr(name, deleteReturn, [{ name: "id", type: "string" }]);
  const get = (name, row) => cr(name, row, [{ name: "id", type: "string" }]);
  const create = (name, req, row) => cr(name, row, [{ name: "input", type: req }]);
  const update = (name, req, row) => cr(name, row, [{ name: "input", type: req }]);

  return {
    listPipelines: cr("listPipelines", "CrmPipelineRow[]"),
    getPipeline: get("getPipeline", "PipelineDetail"),
    createPipeline: create("createPipeline", "CreatePipelineRequest", "CrmPipelineRow"),
    updatePipeline: update("updatePipeline", "UpdatePipelineRequest", "CrmPipelineRow"),
    deletePipeline: del("deletePipeline"),
    listPipelineStages: cr("listPipelineStages", "CrmPipelineStageRow[]", [{ name: "pipelineId", type: "string" }]),
    createPipelineStage: create("createPipelineStage", "CreatePipelineStageRequest", "CrmPipelineStageRow"),
    updatePipelineStage: update("updatePipelineStage", "UpdatePipelineStageRequest", "CrmPipelineStageRow"),
    deletePipelineStage: del("deletePipelineStage"),
    listCampaigns: cr("listCampaigns", "CrmCampaignRow[]", [{ name: "status", optional: true, type: "string" }]),
    getCampaign: get("getCampaign", "CrmCampaignRow"),
    createCampaign: create("createCampaign", "CreateCampaignRequest", "CrmCampaignRow"),
    updateCampaign: update("updateCampaign", "UpdateCampaignRequest", "CrmCampaignRow"),
    deleteCampaign: del("deleteCampaign"),
    listTags: cr("listTags", "CrmTagRow[]"),
    createTag: create("createTag", "CreateTagRequest", "CrmTagRow"),
    updateTag: update("updateTag", "UpdateTagRequest", "CrmTagRow"),
    deleteTag: del("deleteTag"),
    listCompanies: cr("listCompanies", "CrmCompanyRow[]"),
    getCompany: get("getCompany", "CrmCompanyRow"),
    createCompany: create("createCompany", "CreateCompanyRequest", "CrmCompanyRow"),
    updateCompany: update("updateCompany", "UpdateCompanyRequest", "CrmCompanyRow"),
    deleteCompany: del("deleteCompany"),
    listContacts: cr("listContacts", "CrmContactRow[]", [{ name: "status", optional: true, type: "string" }]),
    getContact: get("getContact", "CrmContactRow"),
    createContact: create("createContact", "CreateContactRequest", "CrmContactRow"),
    updateContact: update("updateContact", "UpdateContactRequest", "CrmContactRow"),
    deleteContact: del("deleteContact"),
    listLeads: cr("listLeads", "CrmLeadRow[]", [
      { name: "status", optional: true, type: "string" },
      { name: "campaignId", optional: true, type: "string" },
    ]),
    getLead: get("getLead", "CrmLeadRow"),
    createLead: create("createLead", "CreateLeadRequest", "CrmLeadRow"),
    updateLead: update("updateLead", "UpdateLeadRequest", "CrmLeadRow"),
    deleteLead: del("deleteLead"),
    listContactCompanies: cr("listContactCompanies", "CrmContactCompanyRow[]", [
      { name: "contactId", optional: true, type: "string" },
      { name: "companyId", optional: true, type: "string" },
    ]),
    createContactCompany: create("createContactCompany", "CreateContactCompanyRequest", "CrmContactCompanyRow"),
    updateContactCompany: update("updateContactCompany", "UpdateContactCompanyRequest", "CrmContactCompanyRow"),
    deleteContactCompany: del("deleteContactCompany"),
    listCompanyTenants: cr("listCompanyTenants", "CrmCompanyTenantRow[]", [
      { name: "companyId", optional: true, type: "string" },
    ]),
    createCompanyTenant: create("createCompanyTenant", "CreateCompanyTenantRequest", "CrmCompanyTenantRow"),
    updateCompanyTenant: update("updateCompanyTenant", "UpdateCompanyTenantRequest", "CrmCompanyTenantRow"),
    deleteCompanyTenant: del("deleteCompanyTenant"),
    listContactTenants: cr("listContactTenants", "CrmContactTenantRow[]", [
      { name: "contactId", optional: true, type: "string" },
    ]),
    createContactTenant: create("createContactTenant", "CreateContactTenantRequest", "CrmContactTenantRow"),
    updateContactTenant: update("updateContactTenant", "UpdateContactTenantRequest", "CrmContactTenantRow"),
    deleteContactTenant: del("deleteContactTenant"),
    listOpportunities: cr("listOpportunities", "CrmOpportunityRow[]", [
      { name: "pipelineId", optional: true, type: "string" },
      { name: "stageId", optional: true, type: "string" },
      { name: "status", optional: true, type: "string" },
    ]),
    getOpportunity: get("getOpportunity", "CrmOpportunityRow"),
    createOpportunity: create("createOpportunity", "CreateOpportunityRequest", "CrmOpportunityRow"),
    updateOpportunity: update("updateOpportunity", "UpdateOpportunityRequest", "CrmOpportunityRow"),
    deleteOpportunity: del("deleteOpportunity"),
    listTasks: cr("listTasks", "CrmTaskRow[]", [
      { name: "targetType", optional: true, type: "string" },
      { name: "targetId", optional: true, type: "string" },
      { name: "status", optional: true, type: "string" },
    ]),
    getTask: get("getTask", "CrmTaskRow"),
    createTask: create("createTask", "CreateTaskRequest", "CrmTaskRow"),
    updateTask: update("updateTask", "UpdateTaskRequest", "CrmTaskRow"),
    deleteTask: del("deleteTask"),
    listInteractions: cr("listInteractions", "CrmInteractionRow[]", [
      { name: "contactId", optional: true, type: "string" },
      { name: "leadId", optional: true, type: "string" },
      { name: "opportunityId", optional: true, type: "string" },
      { name: "companyId", optional: true, type: "string" },
      { name: "limit", optional: true, type: "number" },
    ]),
    createInteraction: create("createInteraction", "CreateInteractionRequest", "CrmInteractionRow"),
    softDeleteInteraction: cr("softDeleteInteraction", softDeleteReturn, [{ name: "id", type: "string" }]),
    listNotes: cr("listNotes", "CrmNoteRow[]", [
      { name: "entityType", type: "string" },
      { name: "entityId", type: "string" },
    ]),
    createNote: create("createNote", "CreateNoteRequest", "CrmNoteRow"),
    updateNote: update("updateNote", "UpdateNoteRequest", "CrmNoteRow"),
    deleteNote: del("deleteNote"),
    listTagAssignments: cr("listTagAssignments", "CrmTagAssignmentRow[]", [
      { name: "entityType", optional: true, type: "string" },
      { name: "entityId", optional: true, type: "string" },
    ]),
    createTagAssignment: create("createTagAssignment", "CreateTagAssignmentRequest", "CrmTagAssignmentRow"),
    deleteTagAssignment: del("deleteTagAssignment"),
    listLists: cr("listLists", "CrmListRow[]"),
    getList: get("getList", "CrmListRow"),
    createList: create("createList", "CreateListRequest", "CrmListRow"),
    updateList: update("updateList", "UpdateListRequest", "CrmListRow"),
    deleteList: del("deleteList"),
    listListMembers: cr("listListMembers", "CrmListMemberRow[]", [{ name: "listId", type: "string" }]),
    createListMember: create("createListMember", "CreateListMemberRequest", "CrmListMemberRow"),
    deleteListMember: del("deleteListMember"),
    listCustomFields: cr("listCustomFields", "CrmCustomFieldRow[]", [
      { name: "appliesTo", optional: true, type: "string" },
    ]),
    createCustomField: create("createCustomField", "CreateCustomFieldRequest", "CrmCustomFieldRow"),
    updateCustomField: update("updateCustomField", "UpdateCustomFieldRequest", "CrmCustomFieldRow"),
    deleteCustomField: del("deleteCustomField"),
    listCustomFieldValues: cr("listCustomFieldValues", "CrmCustomFieldValueRow[]", [
      { name: "entityType", optional: true, type: "string" },
      { name: "entityId", optional: true, type: "string" },
      { name: "customFieldId", optional: true, type: "string" },
    ]),
    upsertCustomFieldValue: create("upsertCustomFieldValue", "UpsertCustomFieldValueRequest", "CrmCustomFieldValueRow"),
    updateCustomFieldValue: update("updateCustomFieldValue", "UpdateCustomFieldValueRequest", "CrmCustomFieldValueRow"),
    deleteCustomFieldValue: del("deleteCustomFieldValue"),
  };
}

DEFS.crm = crmDefs();

const TARGET_MODULES = ["optimization", "monetization", "operations", "preconfig", "crm"];

for (const module of TARGET_MODULES) {
  const indexPath = path.join(root, module, "index.ts");
  const servicePath = path.join(root, module, "service.ts");
  const typesPath = path.join(root, module, "types.ts");
  const moduleDefs = DEFS[module];
  const fnNames = extractFnNames(indexPath);
  const missing = fnNames.filter((n) => !moduleDefs[n]);
  if (missing.length) {
    console.error(`${module}: missing defs for ${missing.join(", ")}`);
    process.exitCode = 1;
    continue;
  }
  const typesText = fs.readFileSync(typesPath, "utf8");
  const typeImports = collectTypes(moduleDefs, typesText);
  const header = [
    `import { type AuthContext, requireTenant } from "../shared/auth.ts";`,
    `import { callModuleApiAuth } from "../shared/edge-rpc.ts";`,
    typeImports.length
      ? `import type {\n  ${typeImports.join(",\n  ")},\n} from "./types.ts";`
      : "",
    "",
    "function tid(auth: AuthContext): string {",
    "  return requireTenant(auth);",
    "}",
    "",
  ].join("\n");
  const body = fnNames.map((name) => buildFn(module, name, moduleDefs[name])).join("\n\n");
  fs.writeFileSync(servicePath, `${header}\n${body}\n`);
  console.log(`${module}: ${fnNames.length} functions`);
}
