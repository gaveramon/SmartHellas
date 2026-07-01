import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { rulesHandler } from "./handlers/rules.ts";
import { ruleHandler } from "./handlers/rule.ts";
import { insightsHandler } from "./handlers/insights.ts";
import { insightHandler } from "./handlers/insight.ts";
import { recommendationsHandler } from "./handlers/recommendations.ts";
import { recommendationHandler } from "./handlers/recommendation.ts";
import { usageScoresHandler } from "./handlers/usage_scores.ts";
import { energyProfilesHandler } from "./handlers/energy_profiles.ts";
import { energyProfileHandler } from "./handlers/energy_profile.ts";

export const resolveRoute = createRouteResolver("optimization");

export const routeHandlers: RouteHandlerMap = {
  "rules": rulesHandler,
  "rule": ruleHandler,
  "insights": insightsHandler,
  "insight": insightHandler,
  "recommendations": recommendationsHandler,
  "recommendation": recommendationHandler,
  "usage-scores": usageScoresHandler,
  "energy-profiles": energyProfilesHandler,
  "energy-profile": energyProfileHandler,
};
