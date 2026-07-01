import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  AutomationRunDetail,
  AutomationRunRow,
  AutomationRunStepRow,
  AutomationSubscriptionRow,
  CancelRunRequest,
  DeleteSubscriptionRequest,
  DispatchEventRequest,
  StartRunRequest,
  UpsertSubscriptionRequest,
} from "./types.ts";

function tid(auth: AuthContext): string {
  return requireTenant(auth);
}

export async function listRuns(
  auth: AuthContext,
  workflowId?: string,
): Promise<AutomationRunRow[]> {
  tid(auth);
  return await callModuleApiAuth<AutomationRunRow[]>(
    auth,
    "automation",
    "list_runs",
    workflowId ? { workflow_id: workflowId } : {},
  );
}

export async function getRun(auth: AuthContext, id: string): Promise<AutomationRunDetail> {
  tid(auth);
  return await callModuleApiAuth<AutomationRunDetail>(auth, "automation", "get_run", { id });
}

export async function listRunSteps(
  auth: AuthContext,
  runId: string,
): Promise<AutomationRunStepRow[]> {
  tid(auth);
  return await callModuleApiAuth<AutomationRunStepRow[]>(
    auth,
    "automation",
    "list_run_steps",
    { run_id: runId },
  );
}

export async function dispatchEvent(
  auth: AuthContext,
  input: DispatchEventRequest,
): Promise<{ dispatched: number; run_ids: string[] }> {
  return await callModuleApiAuth(auth, "automation", "dispatch_event", { ...input });
}

export async function startRun(
  auth: AuthContext,
  input: StartRunRequest,
): Promise<AutomationRunRow> {
  return await callModuleApiAuth<AutomationRunRow>(auth, "automation", "start_run", { ...input });
}

export async function cancelRun(
  auth: AuthContext,
  input: CancelRunRequest,
): Promise<{ id: string; status: string; completed_at: string | null }> {
  return await callModuleApiAuth(auth, "automation", "cancel_run", { ...input });
}

export async function listSubscriptions(
  auth: AuthContext,
  workflowId?: string,
): Promise<AutomationSubscriptionRow[]> {
  tid(auth);
  return await callModuleApiAuth<AutomationSubscriptionRow[]>(
    auth,
    "automation",
    "list_subscriptions",
    workflowId ? { workflow_id: workflowId } : {},
  );
}

export async function upsertSubscription(
  auth: AuthContext,
  input: UpsertSubscriptionRequest,
): Promise<AutomationSubscriptionRow> {
  return await callModuleApiAuth<AutomationSubscriptionRow>(
    auth,
    "automation",
    "upsert_subscription",
    { ...input },
  );
}

export async function deleteSubscription(
  auth: AuthContext,
  input: DeleteSubscriptionRequest,
): Promise<{ deleted: true; id: string }> {
  tid(auth);
  return await callModuleApiAuth(auth, "automation", "delete_subscription", { ...input });
}
