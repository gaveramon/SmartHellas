import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { enqueueHandler } from "./handlers/enqueue.ts";
import { historyHandler } from "./handlers/history.ts";
import { preferencesHandler } from "./handlers/preferences.ts";
import { queueHandler } from "./handlers/queue.ts";
import { templatesHandler } from "./handlers/templates.ts";
import { templateHandler } from "./handlers/template.ts";
import { notificationHandler } from "./handlers/notification.ts";

export const resolveRoute = createRouteResolver("notifications");

export const routeHandlers: RouteHandlerMap = {
  "templates": templatesHandler,
  "template": templateHandler,
  "preferences": preferencesHandler,
  "enqueue": enqueueHandler,
  "queue": queueHandler,
  "history": historyHandler,
  "notification": notificationHandler,
};
