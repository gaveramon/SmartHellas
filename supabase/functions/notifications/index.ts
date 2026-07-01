import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createAuthenticatedApp } from "../shared/core/index.ts";
import { resolveRoute, routeHandlers } from "./route.ts";

Deno.serve(
  createAuthenticatedApp({
    functionName: "notifications",
    resolveRoute,
    handlers: routeHandlers,
  }),
);
