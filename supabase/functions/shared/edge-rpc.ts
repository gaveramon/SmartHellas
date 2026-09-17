import type { AuthContext } from "./auth.ts";
import { callPublicRpc } from "./database.ts";
import type { DatabaseClient } from "./supabase.ts";
import { createServiceClient } from "./supabase.ts";

/**
 * Invoke a module Edge API RPC (SQL SSOT).
 * Each module exposes `{module}_api(p_op, p_payload)` in public schema.
 */
export async function callModuleApi<T>(
  client: DatabaseClient,
  module: string,
  op: string,
  payload: Record<string, unknown> = {},
): Promise<T> {
  return callPublicRpc<T>(client, `${module}_api`, {
    p_op: op,
    p_payload: payload,
  });
}

export async function callModuleApiAuth<T>(
  auth: AuthContext,
  module: string,
  op: string,
  payload: Record<string, unknown> = {},
): Promise<T> {
  return callModuleApi<T>(auth.client, module, op, payload);
}

/** Service-role module API (OAuth callbacks, workers). */
export async function callModuleApiService<T>(
  module: string,
  op: string,
  payload: Record<string, unknown> = {},
): Promise<T> {
  return callModuleApi<T>(createServiceClient(), module, op, payload);
}
