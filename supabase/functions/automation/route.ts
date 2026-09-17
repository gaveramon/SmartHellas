import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { runsHandler } from "./handlers/runs.ts";
import { runHandler } from "./handlers/run.ts";
import { runStepsHandler } from "./handlers/run_steps.ts";
import { dispatchHandler } from "./handlers/dispatch.ts";
import { subscriptionsHandler } from "./handlers/subscriptions.ts";
import { subscriptionHandler } from "./handlers/subscription.ts";

export const resolveRoute = createRouteResolver("automation");

export const routeHandlers: RouteHandlerMap = {
  "runs": runsHandler,
  "run": runHandler,
  "run-steps": runStepsHandler,
  "dispatch": dispatchHandler,
  "subscriptions": subscriptionsHandler,
  "subscription": subscriptionHandler,
};
