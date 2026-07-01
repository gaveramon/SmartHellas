import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { plansHandler } from "./handlers/plans.ts";
import { planHandler } from "./handlers/plan.ts";
import { planPricingHandler } from "./handlers/plan_pricing.ts";
import { planPricingEntryHandler } from "./handlers/plan_pricing_entry.ts";
import { entitlementsHandler } from "./handlers/entitlements.ts";
import { entitlementHandler } from "./handlers/entitlement.ts";
import { upsellRulesHandler } from "./handlers/upsell_rules.ts";
import { upsellRuleHandler } from "./handlers/upsell_rule.ts";
import { myEntitlementsHandler } from "./handlers/my_entitlements.ts";
import { changePlanHandler } from "./handlers/change_plan.ts";

export const resolveRoute = createRouteResolver("commerce");

export const routeHandlers: RouteHandlerMap = {
  "plans": plansHandler,
  "plan": planHandler,
  "plan-pricing": planPricingHandler,
  "plan-pricing-entry": planPricingEntryHandler,
  "entitlements": entitlementsHandler,
  "entitlement": entitlementHandler,
  "upsell-rules": upsellRulesHandler,
  "upsell-rule": upsellRuleHandler,
  "my-entitlements": myEntitlementsHandler,
  "change-plan": changePlanHandler,
};
