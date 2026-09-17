import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  CancelNotificationRequest,
  EnqueueNotificationRequest,
  NotificationHistoryRow,
  NotificationPreferenceRow,
  NotificationQueueRow,
  NotificationTemplateRow,
  UpsertPreferenceRequest,
} from "./types.ts";

async function tid(auth: AuthContext): Promise<string> {
  return await requireTenant(auth);
}

export async function listTemplates(auth: AuthContext): Promise<NotificationTemplateRow[]> {
  await tid(auth);
  return await callModuleApiAuth<NotificationTemplateRow[]>(
    auth,
    "notification",
    "list_templates",
  );
}

export async function getTemplate(auth: AuthContext, id: string): Promise<NotificationTemplateRow> {
  await tid(auth);
  return await callModuleApiAuth<NotificationTemplateRow>(auth, "notification", "get_template", {
    id,
  });
}

export async function createTemplate(
  auth: AuthContext,
  input: Record<string, unknown>,
): Promise<NotificationTemplateRow> {
  return await callModuleApiAuth<NotificationTemplateRow>(
    auth,
    "notification",
    "create_template",
    input,
  );
}

export async function updateTemplate(
  auth: AuthContext,
  input: Record<string, unknown>,
): Promise<NotificationTemplateRow> {
  return await callModuleApiAuth<NotificationTemplateRow>(
    auth,
    "notification",
    "update_template",
    input,
  );
}

export async function deleteTemplate(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "notification", "delete_template", { id });
}

export async function listPreferences(
  auth: AuthContext,
  userId?: string,
): Promise<NotificationPreferenceRow[]> {
  await tid(auth);
  return await callModuleApiAuth<NotificationPreferenceRow[]>(
    auth,
    "notification",
    "list_preferences",
    userId ? { user_id: userId } : {},
  );
}

export async function upsertPreference(
  auth: AuthContext,
  input: UpsertPreferenceRequest,
): Promise<NotificationPreferenceRow> {
  return await callModuleApiAuth<NotificationPreferenceRow>(
    auth,
    "notification",
    "upsert_preference",
    { ...input },
  );
}

export async function enqueueNotification(
  auth: AuthContext,
  input: EnqueueNotificationRequest,
): Promise<NotificationQueueRow | { skipped: true; reason: string }> {
  return await callModuleApiAuth(auth, "notification", "enqueue_notification", { ...input });
}

export async function listQueue(
  auth: AuthContext,
  status?: string,
): Promise<NotificationQueueRow[]> {
  await tid(auth);
  return await callModuleApiAuth<NotificationQueueRow[]>(
    auth,
    "notification",
    "list_queue",
    status ? { status } : {},
  );
}

export async function getNotification(
  auth: AuthContext,
  id: string,
): Promise<NotificationHistoryRow> {
  await tid(auth);
  return await callModuleApiAuth<NotificationHistoryRow>(auth, "notification", "get_notification", {
    id,
  });
}

export async function listHistory(
  auth: AuthContext,
  channel?: string,
): Promise<NotificationHistoryRow[]> {
  await tid(auth);
  return await callModuleApiAuth<NotificationHistoryRow[]>(
    auth,
    "notification",
    "list_history",
    channel ? { channel } : {},
  );
}

export async function cancelNotification(
  auth: AuthContext,
  input: CancelNotificationRequest,
): Promise<{ cancelled: true; id: string }> {
  return await callModuleApiAuth(auth, "notification", "cancel_notification", { ...input });
}
