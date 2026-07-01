import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { bundlesHandler } from "./handlers/bundles.ts";
import { bundleHandler } from "./handlers/bundle.ts";
import { bundleDevicesHandler } from "./handlers/bundle_devices.ts";
import { bundleDeviceHandler } from "./handlers/bundle_device.ts";
import { blueprintsHandler } from "./handlers/blueprints.ts";
import { blueprintHandler } from "./handlers/blueprint.ts";
import { blueprintStepsHandler } from "./handlers/blueprint_steps.ts";
import { blueprintStepHandler } from "./handlers/blueprint_step.ts";
import { templatesHandler } from "./handlers/templates.ts";
import { templateHandler } from "./handlers/template.ts";
import { deviceMapHandler } from "./handlers/device_map.ts";
import { deviceMapEntryHandler } from "./handlers/device_map_entry.ts";

export const resolveRoute = createRouteResolver("preconfig");

export const routeHandlers: RouteHandlerMap = {
  "bundles": bundlesHandler,
  "bundle": bundleHandler,
  "bundle-devices": bundleDevicesHandler,
  "bundle-device": bundleDeviceHandler,
  "blueprints": blueprintsHandler,
  "blueprint": blueprintHandler,
  "blueprint-steps": blueprintStepsHandler,
  "blueprint-step": blueprintStepHandler,
  "templates": templatesHandler,
  "template": templateHandler,
  "device-map": deviceMapHandler,
  "device-map-entry": deviceMapEntryHandler,
};
