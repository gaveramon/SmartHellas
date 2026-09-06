import { config } from "./config.ts";
import { logPlatformEvent } from "./database.ts";

export interface LogContext {
  functionName: string;
  correlationId?: string;
  tenantId?: string;
  userId?: string;
  route?: string;
}

export function createLogger(ctx: LogContext) {
  const correlationId = ctx.correlationId ?? crypto.randomUUID();
  const base = {
    function: ctx.functionName,
    correlation_id: correlationId,
    tenant_id: ctx.tenantId,
    user_id: ctx.userId,
    route: ctx.route,
    environment: config.environment(),
  };

  return {
    correlationId,

    info(message: string, extra?: Record<string, unknown>) {
      const entry = { level: "info", message, ...base, ...extra };
      console.log(JSON.stringify(entry));
    },

    warn(message: string, extra?: Record<string, unknown>) {
      const entry = { level: "warn", message, ...base, ...extra };
      console.warn(JSON.stringify(entry));
    },

    error(message: string, extra?: Record<string, unknown>) {
      const entry = { level: "error", message, ...base, ...extra };
      console.error(JSON.stringify(entry));
    },

    /** Persist execution trail to platform.event_log when tenant context is available. */
    async audit(
      eventType: string,
      payload: Record<string, unknown> = {},
      severity = "info",
    ) {
      try {
        await logPlatformEvent(
          eventType,
          ctx.functionName,
          { ...payload, route: ctx.route },
          severity,
          correlationId,
        );
      } catch (e) {
        console.error(
          JSON.stringify({
            level: "error",
            message: "Failed to write platform event log",
            error: e instanceof Error ? e.message : String(e),
            ...base,
          }),
        );
      }
    },
  };
}
