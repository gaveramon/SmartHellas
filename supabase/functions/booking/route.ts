import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { bookingsHandler } from "./handlers/bookings.ts";
import { bookingHandler } from "./handlers/booking.ts";
import { accessScheduleHandler } from "./handlers/access_schedule.ts";
import { bookingAccessHandler } from "./handlers/booking_access.ts";
import { accessPoliciesHandler } from "./handlers/access_policies.ts";
import { accessPolicyHandler } from "./handlers/access_policy.ts";
import { accessRulesHandler } from "./handlers/access_rules.ts";
import { accessRuleHandler } from "./handlers/access_rule.ts";

export const resolveRoute = createRouteResolver("booking");

export const routeHandlers: RouteHandlerMap = {
  "bookings": bookingsHandler,
  "booking": bookingHandler,
  "access-schedule": accessScheduleHandler,
  "booking-access": bookingAccessHandler,
  "access-policies": accessPoliciesHandler,
  "access-policy": accessPolicyHandler,
  "access-rules": accessRulesHandler,
  "access-rule": accessRuleHandler,
};
