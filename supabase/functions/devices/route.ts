import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { propertiesHandler } from "./handlers/properties.ts";
import { propertyHandler } from "./handlers/property.ts";
import { roomsHandler } from "./handlers/rooms.ts";
import { roomHandler } from "./handlers/room.ts";
import { categoriesHandler } from "./handlers/categories.ts";
import { devicesHandler } from "./handlers/devices.ts";
import { deviceHandler } from "./handlers/device.ts";
import { assignHandler } from "./handlers/assign.ts";
import { unassignHandler } from "./handlers/unassign.ts";
import { deviceConfigHandler } from "./handlers/device_config.ts";

export const resolveRoute = createRouteResolver("devices");

export const routeHandlers: RouteHandlerMap = {
  "properties": propertiesHandler,
  "property": propertyHandler,
  "rooms": roomsHandler,
  "room": roomHandler,
  "categories": categoriesHandler,
  "devices": devicesHandler,
  "device": deviceHandler,
  "assign": assignHandler,
  "unassign": unassignHandler,
  "device-config": deviceConfigHandler,
};
