/**
 * Environment configuration for Edge Functions.
 * All secrets must be set in Supabase project secrets / .env.local.
 */

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function optionalEnv(name: string): string | undefined {
  return Deno.env.get(name) ?? undefined;
}

export const config = {
  supabaseUrl: () => requireEnv("SUPABASE_URL"),
  supabaseAnonKey: () => requireEnv("SUPABASE_ANON_KEY"),
  supabaseServiceRoleKey: () => requireEnv("SUPABASE_SERVICE_ROLE_KEY"),

  /** Direct Postgres URL for platform-schema RPCs (not exposed via PostgREST). */
  databaseUrl: () =>
    optionalEnv("SUPABASE_DB_URL") ??
    optionalEnv("DATABASE_URL") ??
    requireEnv("SUPABASE_DB_URL"),

  stripeSecretKey: () => optionalEnv("STRIPE_SECRET_KEY"),
  stripeWebhookSecret: () => optionalEnv("STRIPE_WEBHOOK_SECRET"),

  ttlockClientId: () => optionalEnv("TTLOCK_CLIENT_ID"),
  ttlockClientSecret: () => optionalEnv("TTLOCK_CLIENT_SECRET"),

  aqaraAppId: () => optionalEnv("AQARA_APP_ID"),
  aqaraAppKey: () => optionalEnv("AQARA_APP_KEY"),

  mailProvider: () => optionalEnv("MAIL_PROVIDER") ?? "supabase",
  mailApiKey: () => optionalEnv("MAIL_API_KEY"),
  mailFrom: () => optionalEnv("MAIL_FROM") ?? "noreply@smarthellas.com",

  smsProvider: () => optionalEnv("SMS_PROVIDER"),
  smsApiKey: () => optionalEnv("SMS_API_KEY"),
  smsFrom: () => optionalEnv("SMS_FROM"),

  environment: () => optionalEnv("ENVIRONMENT") ?? "development",
  isProduction: () => config.environment() === "production",

  /** Shared secret for cron/worker invocations (optional; service role also accepted). */
  jobSecret: () => optionalEnv("JOB_SECRET"),

  /** Identifier for edge worker node heartbeats. */
  nodeIdentifier: () =>
    optionalEnv("NODE_IDENTIFIER") ?? "edge-functions-default",
};
