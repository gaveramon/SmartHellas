import { getUserId, requireAuth, requireTenant, type AuthContext } from "../auth.ts";
import { createLogger, type LogContext } from "../logger.ts";
import type { EdgeLogger } from "../core/types.ts";

export interface RequestMiddlewareResult {
  auth: AuthContext;
  logger: EdgeLogger;
}

/** Build authenticated request context for manual handler pipelines. */
export async function buildAuthenticatedContext(
  req: Request,
  logContext: Omit<LogContext, "userId" | "tenantId">,
  options?: { resolveTenant?: boolean },
): Promise<RequestMiddlewareResult> {
  let auth = await requireAuth(req);
  let tenantId: string | undefined;
  if (options?.resolveTenant !== false) {
    tenantId = await requireTenant(auth);
  }
  const logger = createLogger({
    ...logContext,
    userId: getUserId(auth),
    tenantId,
  });
  return { auth, logger };
}
