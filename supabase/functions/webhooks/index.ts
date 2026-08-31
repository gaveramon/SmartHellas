import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createAuthenticatedApp } from "../shared/core/index.ts";
import { resolveRoute, routeHandlers } from "./route.ts";

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FUNCTION_NAME = "webhooks";

Deno.serve(
  createAuthenticatedApp({
    functionName: FUNCTION_NAME,
    resolveRoute,
    handlers: routeHandlers,
    resolveTenant: false,
    publicRoutes: new Set(["ingest", "stripe", "receive"]),
  }),
);