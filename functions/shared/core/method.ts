import { ValidationError } from "../errors.ts";
import type { HandlerContext, RouteHandler } from "./types.ts";

/**
 * Restrict a handler to specific HTTP methods.
 * Throws ValidationError when method does not match.
 */
export function withMethod(
  methods: readonly string[],
  handler: (ctx: HandlerContext) => Promise<Response>,
  routeLabel?: string,
): RouteHandler {
  const allowed = new Set(methods);
  const label = routeLabel ?? "this route";

  return async (ctx) => {
    if (!allowed.has(ctx.req.method)) {
      throw new ValidationError(
        `${methods.join(", ")} required for ${label}`,
      );
    }
    return handler(ctx);
  };
}

/**
 * Dispatch to method-specific handlers without switch statements.
 */
export function dispatchMethod(
  handlers: Record<string, (ctx: HandlerContext) => Promise<Response>>,
  routeLabel: string,
): RouteHandler {
  const methods = Object.keys(handlers);

  return async (ctx) => {
    const handler = handlers[ctx.req.method];
    if (!handler) {
      throw new ValidationError(
        `${methods.join(", ")} required for ${routeLabel}`,
      );
    }
    return handler(ctx);
  };
}
