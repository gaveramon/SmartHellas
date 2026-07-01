import { requireAuth, resolveTenantId } from "../auth.ts";
import { ValidationError } from "../errors.ts";
import { createLogger } from "../logger.ts";
import { withErrorHandling } from "../response.ts";
import { lookupHandler, lookupJobHandler } from "./route.ts";
import type {
  HandlerContext,
  JobHandlerContext,
  JobRouteHandlerMap,
  RouteHandlerMap,
} from "./types.ts";

export interface AuthenticatedAppConfig {
  functionName: string;
  resolveRoute: (req: Request) => string;
  handlers: RouteHandlerMap;
  /** Routes that skip JWT auth (e.g. OAuth callbacks). */
  publicRoutes?: ReadonlySet<string>;
  /**
   * When true (default), resolve tenant from JWT app_metadata and verify access.
   * Disable for auth routes that manage tenant context explicitly.
   */
  resolveTenant?: boolean;
}

export interface JobAppConfig {
  functionName: string;
  resolveRoute: (req: Request) => string;
  handlers: JobRouteHandlerMap;
  authenticate: (req: Request) => void;
}

/** Standard authenticated Edge Function entrypoint factory. */
export function createAuthenticatedApp(config: AuthenticatedAppConfig) {
  const publicRoutes = config.publicRoutes ?? new Set<string>();

  return withErrorHandling(async (req: Request) => {
    const route = config.resolveRoute(req);
    const handler = lookupHandler(config.handlers, route);
    const isPublic = publicRoutes.has(route);

    if (isPublic) {
      const logger = createLogger({
        functionName: config.functionName,
        route,
      });
      logger.info("request_received", { method: req.method, route });

      try {
        const ctx: HandlerContext = {
          req,
          auth: null as unknown as HandlerContext["auth"],
          logger,
        };
        return await handler(ctx);
      } catch (error) {
        logger.error("request_failed", {
          error: error instanceof Error ? error.message : String(error),
        });
        throw error;
      }
    }

    let auth = await requireAuth(req);
    const resolveTenant = config.resolveTenant !== false;
    if (resolveTenant) {
      const tenantId = await resolveTenantId(req, auth);
      auth = { ...auth, tenantId };
    }

    const logger = createLogger({
      functionName: config.functionName,
      userId: auth.userId,
      tenantId: auth.tenantId ?? undefined,
      route,
    });

    logger.info("request_received", { method: req.method, route });

    try {
      const ctx: HandlerContext = { req, auth, logger };
      return await handler(ctx);
    } catch (error) {
      logger.error("request_failed", {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });
}

/** Platform job worker entrypoint factory. */
export function createJobApp(config: JobAppConfig) {
  return withErrorHandling(async (req: Request) => {
    config.authenticate(req);

    if (req.method !== "POST") {
      throw new ValidationError("POST required for all job routes");
    }

    const route = config.resolveRoute(req);
    const handler = lookupJobHandler(config.handlers, route);

    const correlationId = crypto.randomUUID();
    const logger = createLogger({
      functionName: config.functionName,
      correlationId,
      route,
    });

    logger.info("job_request_received", { method: req.method, route });

    try {
      const ctx: JobHandlerContext = { req, logger, correlationId };
      return await handler(ctx);
    } catch (error) {
      logger.error("request_failed", {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });
}
