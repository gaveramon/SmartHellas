import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { ingestHandler } from "./handlers/ingest.ts";
import { stripeHandler } from "./handlers/stripe.ts";
import { receiveHandler } from "./handlers/receive.ts";

export const resolveRoute = createRouteResolver("webhooks");

export const routeHandlers: RouteHandlerMap = {
  "ingest": ingestHandler,
  "stripe": stripeHandler,
  "receive": receiveHandler,
};
