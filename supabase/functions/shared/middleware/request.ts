import { requireAuth, resolveTenantId, type AuthContext } from "../auth.ts";
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
  if (options?.resolveTenant !== false) {
    const tenantId = await resolveTenantId(req, auth);
    auth = { ...auth, tenantId };
  }
  const logger = createLogger({
    ...logContext,
    userId: auth.userId,
    tenantId: auth.tenantId,
  });
  return { auth, logger };
}
