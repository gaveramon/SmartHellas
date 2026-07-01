export interface OperationTemplateRow {
  id: string;
  tenant_id: string | null;
  is_system: boolean;
  name: string;
  description: string | null;
  template: Record<string, unknown>;
  version: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface OperationWorkflowRow {
  id: string;
  tenant_id: string;
  source_template_id: string | null;
  name: string;
  description: string | null;
  is_active: boolean;
  version: number;
  created_at: string;
  updated_at: string;
}

export interface WorkflowStepRow {
  id: string;
  tenant_id: string;
  workflow_id: string;
  step_order: number;
  action_type: string;
  config: Record<string, unknown>;
  delay_seconds: number;
  created_at: string;
}

export interface WorkflowTriggerRow {
  id: string;
  tenant_id: string;
  workflow_id: string;
  property_id: string | null;
  trigger_type: string;
  trigger_config: Record<string, unknown>;
  is_active: boolean;
  created_at: string;
}

export interface WorkflowDetail {
  workflow: OperationWorkflowRow;
  steps: WorkflowStepRow[];
  triggers: WorkflowTriggerRow[];
}

export interface SupportTicketRow {
  id: string;
  tenant_id: string;
  user_id: string | null;
  subject: string | null;
  description: string | null;
  status: string;
  priority: string;
  created_at: string;
  updated_at: string;
}

export interface SupportMessageRow {
  id: string;
  tenant_id: string;
  ticket_id: string;
  sender_type: string;
  message: string | null;
  created_at: string;
}

export interface CreateTemplateRequest {
  name: string;
  description?: string;
  template: Record<string, unknown>;
  version?: number;
  is_active?: boolean;
}

export interface UpdateTemplateRequest {
  id: string;
  name?: string;
  description?: string | null;
  template?: Record<string, unknown>;
  version?: number;
  is_active?: boolean;
}

export interface CreateWorkflowRequest {
  name: string;
  description?: string;
  source_template_id?: string;
  is_active?: boolean;
  version?: number;
}

export interface UpdateWorkflowRequest {
  id: string;
  name?: string;
  description?: string | null;
  source_template_id?: string | null;
  is_active?: boolean;
  version?: number;
}

export interface CreateWorkflowStepRequest {
  workflow_id: string;
  step_order: number;
  action_type: string;
  config?: Record<string, unknown>;
  delay_seconds?: number;
}

export interface UpdateWorkflowStepRequest {
  id: string;
  step_order?: number;
  action_type?: string;
  config?: Record<string, unknown>;
  delay_seconds?: number;
}

export interface CreateWorkflowTriggerRequest {
  workflow_id: string;
  trigger_type: string;
  property_id?: string;
  trigger_config?: Record<string, unknown>;
  is_active?: boolean;
}

export interface UpdateWorkflowTriggerRequest {
  id: string;
  trigger_type?: string;
  property_id?: string | null;
  trigger_config?: Record<string, unknown>;
  is_active?: boolean;
}

export interface CreateSupportTicketRequest {
  subject?: string;
  description?: string;
  priority?: string;
  user_id?: string;
}

export interface UpdateSupportTicketRequest {
  id: string;
  subject?: string | null;
  description?: string | null;
  status?: string;
  priority?: string;
  user_id?: string | null;
}

export interface CreateSupportMessageRequest {
  ticket_id: string;
  message: string;
  sender_type?: string;
}
