import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { checkoutHandler } from "./handlers/checkout.ts";
import { paymentHandler } from "./handlers/payment.ts";
import { paymentsHandler } from "./handlers/payments.ts";
import { historyHandler } from "./handlers/history.ts";

export const resolveRoute = createRouteResolver("payments");

export const routeHandlers: RouteHandlerMap = {
  "checkout": checkoutHandler,
  "payments": paymentsHandler,
  "payment": paymentHandler,
  "history": historyHandler,
};
