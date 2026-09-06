import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { templatesHandler } from "./handlers/templates.ts";
import { templateHandler } from "./handlers/template.ts";
import { workflowsHandler } from "./handlers/workflows.ts";
import { workflowHandler } from "./handlers/workflow.ts";
import { workflowStepsHandler } from "./handlers/workflow_steps.ts";
import { workflowStepHandler } from "./handlers/workflow_step.ts";
import { workflowTriggersHandler } from "./handlers/workflow_triggers.ts";
import { workflowTriggerHandler } from "./handlers/workflow_trigger.ts";
import { supportTicketsHandler } from "./handlers/support_tickets.ts";
import { supportTicketHandler } from "./handlers/support_ticket.ts";
import { supportMessagesHandler } from "./handlers/support_messages.ts";

export const resolveRoute = createRouteResolver("operations");

export const routeHandlers: RouteHandlerMap = {
  "templates": templatesHandler,
  "template": templateHandler,
  "workflows": workflowsHandler,
  "workflow": workflowHandler,
  "workflow-steps": workflowStepsHandler,
  "workflow-step": workflowStepHandler,
  "workflow-triggers": workflowTriggersHandler,
  "workflow-trigger": workflowTriggerHandler,
  "support-tickets": supportTicketsHandler,
  "support-ticket": supportTicketHandler,
  "support-messages": supportMessagesHandler,
};
