import type { AuthContext } from "../auth.ts";
import type { createLogger } from "../logger.ts";

export type EdgeLogger = ReturnType<typeof createLogger>;

/** Immutable per-request context passed to route handlers. */
export interface HandlerContext {
  readonly req: Request;
  readonly auth: AuthContext;
  readonly logger: EdgeLogger;
}

/** Job workers use correlation id instead of user auth. */
export interface JobHandlerContext {
  readonly req: Request;
  readonly logger: EdgeLogger;
  readonly correlationId: string;
}

export type RouteHandler = (ctx: HandlerContext) => Promise<Response>;
export type JobRouteHandler = (ctx: JobHandlerContext) => Promise<Response>;

export type RouteHandlerMap = Record<string, RouteHandler>;
export type JobRouteHandlerMap = Record<string, JobRouteHandler>;
