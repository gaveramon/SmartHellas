import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { bootstrapHandler } from "./handlers/bootstrap.ts";
import { settingsHandler } from "./handlers/settings.ts";
import { dashboardsHandler } from "./handlers/dashboards.ts";
import { dashboardHandler } from "./handlers/dashboard.ts";
import { preferencesHandler } from "./handlers/preferences.ts";
import { preferenceHandler } from "./handlers/preference.ts";
import { featureFlagsHandler } from "./handlers/feature_flags.ts";
import { featureFlagHandler } from "./handlers/feature_flag.ts";

export const resolveRoute = createRouteResolver("portal");

export const routeHandlers: RouteHandlerMap = {
  "bootstrap": bootstrapHandler,
  "settings": settingsHandler,
  "dashboards": dashboardsHandler,
  "dashboard": dashboardHandler,
  "preferences": preferencesHandler,
  "preference": preferenceHandler,
  "feature-flags": featureFlagsHandler,
  "feature-flag": featureFlagHandler,
};
