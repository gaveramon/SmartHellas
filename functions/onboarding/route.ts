import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { sessionsHandler } from "./handlers/sessions.ts";
import { sessionHandler } from "./handlers/session.ts";
import { stepStatesHandler } from "./handlers/step_states.ts";
import { stepStateHandler } from "./handlers/step_state.ts";
import { roomMappingsHandler } from "./handlers/room_mappings.ts";
import { roomMappingHandler } from "./handlers/room_mapping.ts";
import { deviceMappingsHandler } from "./handlers/device_mappings.ts";
import { deviceMappingHandler } from "./handlers/device_mapping.ts";
import { checklistHandler } from "./handlers/checklist.ts";
import { checklistItemHandler } from "./handlers/checklist_item.ts";
import { notesHandler } from "./handlers/notes.ts";
import { noteHandler } from "./handlers/note.ts";
import { lifecycleHandler } from "./handlers/lifecycle.ts";
import { lifecycleTransitionsHandler } from "./handlers/lifecycle_transitions.ts";
import { lifecycleTransitionHandler } from "./handlers/lifecycle_transition.ts";

export const resolveRoute = createRouteResolver("onboarding");

export const routeHandlers: RouteHandlerMap = {
  "sessions": sessionsHandler,
  "session": sessionHandler,
  "step-states": stepStatesHandler,
  "step-state": stepStateHandler,
  "room-mappings": roomMappingsHandler,
  "room-mapping": roomMappingHandler,
  "device-mappings": deviceMappingsHandler,
  "device-mapping": deviceMappingHandler,
  "checklist": checklistHandler,
  "checklist-item": checklistItemHandler,
  "notes": notesHandler,
  "note": noteHandler,
  "lifecycle": lifecycleHandler,
  "lifecycle-transitions": lifecycleTransitionsHandler,
  "lifecycle-transition": lifecycleTransitionHandler,
};
