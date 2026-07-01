import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createAuthenticatedApp } from "../shared/core/index.ts";
import { resolveRoute, routeHandlers } from "./route.ts";

const FUNCTION_NAME = "commerce";

Deno.serve(
  createAuthenticatedApp({
    functionName: FUNCTION_NAME,
    resolveRoute,
    handlers: routeHandlers,
  }),
);
