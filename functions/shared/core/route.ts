import { NotFoundError } from "../errors.ts";
import type { JobRouteHandler, JobRouteHandlerMap, RouteHandler, RouteHandlerMap } from "./types.ts";

/** Create a pathname-based route resolver for a Supabase Edge Function module. */
export function createRouteResolver(moduleName: string) {
  return function resolveRoute(req: Request): string {
    const url = new URL(req.url);
    const segments = url.pathname.split("/").filter(Boolean);
    const idx = segments.indexOf(moduleName);
    if (idx >= 0 && segments.length > idx + 1) {
      return segments[idx + 1];
    }
    return segments[segments.length - 1] ?? "";
  };
}

/** Lookup handler from explicit route map — no switch statements. */
export function lookupHandler(
  handlers: RouteHandlerMap,
  route: string,
): RouteHandler {
  const handler = handlers[route];
  if (!handler) {
    throw new NotFoundError(`Unknown route: ${route}`);
  }
  return handler;
}

/** Lookup job worker handler from explicit route map. */
export function lookupJobHandler(
  handlers: JobRouteHandlerMap,
  route: string,
): JobRouteHandler {
  const handler = handlers[route];
  if (!handler) {
    throw new NotFoundError(`Unknown route: ${route}`);
  }
  return handler;
}
