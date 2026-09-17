import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { config } from "./config.ts";

export type DatabaseClient = SupabaseClient;

/** User-scoped client — forwards JWT so RLS and auth.uid() apply. */
export function createUserClient(accessToken: string): DatabaseClient {
  return createClient(config.supabaseUrl(), config.supabaseAnonKey(), {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

/** Service-role client — bypasses RLS. Use only for orchestration (auth admin, platform ingress). */
export function createServiceClient(): DatabaseClient {
  return createClient(config.supabaseUrl(), config.supabaseServiceRoleKey(), {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}
