import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { oauthCallbackHandler } from "./handlers/oauth_callback.ts";
import { providersHandler } from "./handlers/providers.ts";
import { providerHandler } from "./handlers/provider.ts";
import { capabilitiesHandler } from "./handlers/capabilities.ts";
import { connectionsHandler } from "./handlers/connections.ts";
import { connectionHandler } from "./handlers/connection.ts";
import { connectHandler } from "./handlers/connect.ts";
import { disconnectHandler } from "./handlers/disconnect.ts";
import { webhookDefinitionsHandler } from "./handlers/webhook_definitions.ts";
import { webhookDefinitionHandler } from "./handlers/webhook_definition.ts";
import { deviceMapsHandler } from "./handlers/device_maps.ts";
import { deviceMapHandler } from "./handlers/device_map.ts";
import { oauthStartHandler } from "./handlers/oauth_start.ts";
import { syncHandler } from "./handlers/sync.ts";

export const resolveRoute = createRouteResolver("integrations");

export const routeHandlers: RouteHandlerMap = {
  "oauth-callback": oauthCallbackHandler,
  "providers": providersHandler,
  "provider": providerHandler,
  "capabilities": capabilitiesHandler,
  "connections": connectionsHandler,
  "connection": connectionHandler,
  "connect": connectHandler,
  "disconnect": disconnectHandler,
  "webhook-definitions": webhookDefinitionsHandler,
  "webhook-definition": webhookDefinitionHandler,
  "device-maps": deviceMapsHandler,
  "device-map": deviceMapHandler,
  "oauth-start": oauthStartHandler,
  "sync": syncHandler,
};
