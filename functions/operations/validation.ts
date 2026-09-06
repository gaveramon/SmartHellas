import { ValidationError } from "../shared/errors.ts";
import {
  optionalEnum,
  optionalEnumQuery,
  requireEnum,
} from "../shared/validation.ts";
import type {
  CreateSupportMessageRequest,
  CreateSupportTicketRequest,
  CreateTemplateRequest,
  CreateWorkflowRequest,
  CreateWorkflowStepRequest,
  CreateWorkflowTriggerRequest,
  UpdateSupportTicketRequest,
  UpdateTemplateRequest,
  UpdateWorkflowRequest,
  UpdateWorkflowStepRequest,
  UpdateWorkflowTriggerRequest,
} from "./types.ts";

export { optionalEnumQuery } from "../shared/validation.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const AUTOMATION_TRIGGER_TYPES = [
  "booking_created",
  "booking_started",
  "booking_ended",
  "device_added",
  "manual_trigger",
  "schedule_based",
] as const;

export const AUTOMATION_ACTION_TYPES = [
  "send_notification",
  "update_device",
  "generate_code",
  "update_booking",
  "run_optimization",
  "trigger_webhook",
] as const;

export const SUPPORT_TICKET_STATUSES = [
  "open",
  "in_progress",
  "waiting_customer",
  "resolved",
  "closed",
] as const;

export const PRIORITY_LEVELS = [
  "low",
  "normal",
  "high",
  "urgent",
  "critical",
] as const;

export const SUPPORT_SENDER_TYPES = [
  "user",
  "support",
  "system",
] as const;

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function parseRoute(req: Request): string {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const idx = segments.indexOf("operations");
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

export function parseCreateTemplateBody(body: unknown): CreateTemplateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateTemplateRequest = {
    name: requireStringField(r, "name"),
    template: requireJsonObject(r.template, "template"),
  };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.version !== undefined) {
    if (typeof r.version !== "number" || r.version < 1) {
      throw new ValidationError("version must be a positive integer");
    }
    result.version = r.version;
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateTemplateBody(body: unknown): UpdateTemplateRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateTemplateRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.template !== undefined) result.template = requireJsonObject(r.template, "template");
  if (r.version !== undefined) result.version = r.version as number;
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateWorkflowBody(body: unknown): CreateWorkflowRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateWorkflowRequest = { name: requireStringField(r, "name") };
  if (r.description !== undefined) result.description = String(r.description);
  if (r.source_template_id !== undefined) {
    result.source_template_id = requireUuidField(r, "source_template_id");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  if (r.version !== undefined) result.version = r.version as number;
  return result;
}

export function parseUpdateWorkflowBody(body: unknown): UpdateWorkflowRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateWorkflowRequest = { id: requireUuidField(r, "id") };
  if (r.name !== undefined) result.name = String(r.name);
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.source_template_id !== undefined) {
    result.source_template_id =
      r.source_template_id === null ? null : requireUuidField(r, "source_template_id");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  if (r.version !== undefined) result.version = r.version as number;
  return result;
}

export function parseCreateWorkflowStepBody(body: unknown): CreateWorkflowStepRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const stepOrder = r.step_order;
  if (typeof stepOrder !== "number" || stepOrder <= 0) {
    throw new ValidationError("step_order must be a positive integer");
  }
  const result: CreateWorkflowStepRequest = {
    workflow_id: requireUuidField(r, "workflow_id"),
    step_order: stepOrder,
    action_type: requireEnum(r.action_type, "action_type", AUTOMATION_ACTION_TYPES),
  };
  if (r.config !== undefined) result.config = requireJsonObject(r.config, "config");
  if (r.delay_seconds !== undefined) {
    if (typeof r.delay_seconds !== "number" || r.delay_seconds < 0) {
      throw new ValidationError("delay_seconds must be >= 0");
    }
    result.delay_seconds = r.delay_seconds;
  }
  return result;
}

export function parseUpdateWorkflowStepBody(body: unknown): UpdateWorkflowStepRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateWorkflowStepRequest = { id: requireUuidField(r, "id") };
  if (r.step_order !== undefined) {
    if (typeof r.step_order !== "number" || r.step_order <= 0) {
      throw new ValidationError("step_order must be a positive integer");
    }
    result.step_order = r.step_order;
  }
  if (r.action_type !== undefined) {
    result.action_type = requireEnum(r.action_type, "action_type", AUTOMATION_ACTION_TYPES);
  }
  if (r.config !== undefined) result.config = requireJsonObject(r.config, "config");
  if (r.delay_seconds !== undefined) result.delay_seconds = r.delay_seconds as number;
  return result;
}

export function parseCreateWorkflowTriggerBody(
  body: unknown,
): CreateWorkflowTriggerRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: CreateWorkflowTriggerRequest = {
    workflow_id: requireUuidField(r, "workflow_id"),
    trigger_type: requireEnum(r.trigger_type, "trigger_type", AUTOMATION_TRIGGER_TYPES),
  };
  if (r.property_id !== undefined) result.property_id = requireUuidField(r, "property_id");
  if (r.trigger_config !== undefined) {
    result.trigger_config = requireJsonObject(r.trigger_config, "trigger_config");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseUpdateWorkflowTriggerBody(
  body: unknown,
): UpdateWorkflowTriggerRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateWorkflowTriggerRequest = { id: requireUuidField(r, "id") };
  if (r.trigger_type !== undefined) {
    result.trigger_type = requireEnum(r.trigger_type, "trigger_type", AUTOMATION_TRIGGER_TYPES);
  }
  if (r.property_id !== undefined) {
    result.property_id = r.property_id === null ? null : requireUuidField(r, "property_id");
  }
  if (r.trigger_config !== undefined) {
    result.trigger_config = requireJsonObject(r.trigger_config, "trigger_config");
  }
  if (r.is_active !== undefined) result.is_active = r.is_active as boolean;
  return result;
}

export function parseCreateSupportTicketBody(body: unknown): CreateSupportTicketRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const subject = r.subject;
  const description = r.description;
  if (
    (subject === undefined || subject === null || String(subject).trim() === "") &&
    (description === undefined || description === null || String(description).trim() === "")
  ) {
    throw new ValidationError("subject or description is required");
  }
  const result: CreateSupportTicketRequest = {};
  if (subject !== undefined) result.subject = String(subject);
  if (description !== undefined) result.description = String(description);
  if (r.priority !== undefined) {
    result.priority = requireEnum(r.priority, "priority", PRIORITY_LEVELS);
  }
  if (r.user_id !== undefined) result.user_id = requireUuidField(r, "user_id");
  return result;
}

export function parseUpdateSupportTicketBody(body: unknown): UpdateSupportTicketRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const result: UpdateSupportTicketRequest = { id: requireUuidField(r, "id") };
  if (r.subject !== undefined) result.subject = r.subject as string | null;
  if (r.description !== undefined) result.description = r.description as string | null;
  if (r.status !== undefined) {
    result.status = requireEnum(r.status, "status", SUPPORT_TICKET_STATUSES);
  }
  if (r.priority !== undefined) {
    result.priority = requireEnum(r.priority, "priority", PRIORITY_LEVELS);
  }
  if (r.user_id !== undefined) {
    result.user_id = r.user_id === null ? null : requireUuidField(r, "user_id");
  }
  return result;
}

export function parseCreateSupportMessageBody(body: unknown): CreateSupportMessageRequest {
  if (!body || typeof body !== "object") {
    throw new ValidationError("Request body must be a JSON object");
  }
  const r = body as Record<string, unknown>;
  const message = r.message;
  if (typeof message !== "string" || !message.trim()) {
    throw new ValidationError("message is required");
  }
  const result: CreateSupportMessageRequest = {
    ticket_id: requireUuidField(r, "ticket_id"),
    message: message.trim(),
  };
  if (r.sender_type !== undefined) {
    result.sender_type = requireEnum(r.sender_type, "sender_type", SUPPORT_SENDER_TYPES);
  }
  return result;
}
