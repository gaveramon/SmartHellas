import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createJobApp } from "../shared/core/index.ts";
import { requireJobAuth } from "../shared/job-auth.ts";
import { resolveRoute, routeHandlers } from "./route.ts";

const FUNCTION_NAME = "jobs";

Deno.serve(
  createJobApp({
    functionName: FUNCTION_NAME,
    resolveRoute,
    handlers: routeHandlers,
    authenticate: requireJobAuth,
  }),
);
