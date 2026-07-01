import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  CreateSupportMessageRequest,
  CreateSupportTicketRequest,
  CreateTemplateRequest,
  CreateWorkflowRequest,
  CreateWorkflowStepRequest,
  CreateWorkflowTriggerRequest,
  OperationTemplateRow,
  OperationWorkflowRow,
  SupportMessageRow,
  SupportTicketRow,
  UpdateSupportTicketRequest,
  UpdateTemplateRequest,
  UpdateWorkflowRequest,
  UpdateWorkflowStepRequest,
  UpdateWorkflowTriggerRequest,
  WorkflowDetail,
  WorkflowStepRow,
  WorkflowTriggerRow,
} from "./types.ts";

function tid(auth: AuthContext): string {
  return requireTenant(auth);
}

export async function createSupportMessage(auth: AuthContext, input: CreateSupportMessageRequest): Promise<SupportMessageRow> {
  return await callModuleApiAuth<SupportMessageRow>(auth, "operations", "create_support_message", { ...input });
}

export async function createSupportTicket(auth: AuthContext, input: CreateSupportTicketRequest): Promise<SupportTicketRow> {
  return await callModuleApiAuth<SupportTicketRow>(auth, "operations", "create_support_ticket", { ...input });
}

export async function createTemplate(auth: AuthContext, input: CreateTemplateRequest): Promise<OperationTemplateRow> {
  return await callModuleApiAuth<OperationTemplateRow>(auth, "operations", "create_template", { ...input });
}

export async function createWorkflow(auth: AuthContext, input: CreateWorkflowRequest): Promise<OperationWorkflowRow> {
  return await callModuleApiAuth<OperationWorkflowRow>(auth, "operations", "create_workflow", { ...input });
}

export async function createWorkflowStep(auth: AuthContext, input: CreateWorkflowStepRequest): Promise<WorkflowStepRow> {
  return await callModuleApiAuth<WorkflowStepRow>(auth, "operations", "create_workflow_step", { ...input });
}

export async function createWorkflowTrigger(auth: AuthContext, input: CreateWorkflowTriggerRequest): Promise<WorkflowTriggerRow> {
  return await callModuleApiAuth<WorkflowTriggerRow>(auth, "operations", "create_workflow_trigger", { ...input });
}

export async function deleteSupportTicket(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "operations", "delete_support_ticket", { id: id });
}

export async function deleteTemplate(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "operations", "delete_template", { id: id });
}

export async function deleteWorkflow(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "operations", "delete_workflow", { id: id });
}

export async function deleteWorkflowStep(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "operations", "delete_workflow_step", { id: id });
}

export async function deleteWorkflowTrigger(auth: AuthContext, id: string): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth<{ deleted: true; id: string }>(auth, "operations", "delete_workflow_trigger", { id: id });
}

export async function getSupportTicket(auth: AuthContext, id: string): Promise<SupportTicketRow> {
  tid(auth);
  return await callModuleApiAuth<SupportTicketRow>(auth, "operations", "get_support_ticket", { id: id });
}

export async function getTemplate(auth: AuthContext, id: string): Promise<OperationTemplateRow> {
  tid(auth);
  return await callModuleApiAuth<OperationTemplateRow>(auth, "operations", "get_template", { id: id });
}

export async function getWorkflow(auth: AuthContext, id: string): Promise<WorkflowDetail> {
  tid(auth);
  return await callModuleApiAuth<WorkflowDetail>(auth, "operations", "get_workflow", { id: id });
}

export async function listSupportMessages(auth: AuthContext, ticketId: string): Promise<SupportMessageRow[]> {
  tid(auth);
  return await callModuleApiAuth<SupportMessageRow[]>(auth, "operations", "list_support_messages", { ticket_id: ticketId });
}

export async function listSupportTickets(auth: AuthContext, status?: string, priority?: string): Promise<SupportTicketRow[]> {
  tid(auth);
  const payload: Record<string, unknown> = {};
  if (status !== undefined) payload.status = status;
  if (priority !== undefined) payload.priority = priority;
  return await callModuleApiAuth<SupportTicketRow[]>(auth, "operations", "list_support_tickets", payload);
}

export async function listTemplates(auth: AuthContext): Promise<OperationTemplateRow[]> {
  tid(auth);
  return await callModuleApiAuth<OperationTemplateRow[]>(auth, "operations", "list_templates");
}

export async function listWorkflowSteps(auth: AuthContext, workflowId: string): Promise<WorkflowStepRow[]> {
  tid(auth);
  return await callModuleApiAuth<WorkflowStepRow[]>(auth, "operations", "list_workflow_steps", { workflow_id: workflowId });
}

export async function listWorkflowTriggers(auth: AuthContext, workflowId: string): Promise<WorkflowTriggerRow[]> {
  tid(auth);
  return await callModuleApiAuth<WorkflowTriggerRow[]>(auth, "operations", "list_workflow_triggers", { workflow_id: workflowId });
}

export async function listWorkflows(auth: AuthContext): Promise<OperationWorkflowRow[]> {
  tid(auth);
  return await callModuleApiAuth<OperationWorkflowRow[]>(auth, "operations", "list_workflows");
}

export async function updateSupportTicket(auth: AuthContext, input: UpdateSupportTicketRequest): Promise<SupportTicketRow> {
  return await callModuleApiAuth<SupportTicketRow>(auth, "operations", "update_support_ticket", { ...input });
}

export async function updateTemplate(auth: AuthContext, input: UpdateTemplateRequest): Promise<OperationTemplateRow> {
  return await callModuleApiAuth<OperationTemplateRow>(auth, "operations", "update_template", { ...input });
}

export async function updateWorkflow(auth: AuthContext, input: UpdateWorkflowRequest): Promise<OperationWorkflowRow> {
  return await callModuleApiAuth<OperationWorkflowRow>(auth, "operations", "update_workflow", { ...input });
}

export async function updateWorkflowStep(auth: AuthContext, input: UpdateWorkflowStepRequest): Promise<WorkflowStepRow> {
  return await callModuleApiAuth<WorkflowStepRow>(auth, "operations", "update_workflow_step", { ...input });
}

export async function updateWorkflowTrigger(auth: AuthContext, input: UpdateWorkflowTriggerRequest): Promise<WorkflowTriggerRow> {
  return await callModuleApiAuth<WorkflowTriggerRow>(auth, "operations", "update_workflow_trigger", { ...input });
}
