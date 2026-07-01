import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createWorkflowTrigger, listWorkflowTriggers } from "../service.ts";
import { parseCreateWorkflowTriggerBody, parseUuidQuery } from "../validation.ts";

export const workflowTriggersHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listWorkflowTriggers(auth, parseUuidQuery(req, "workflow_id")),
              );
            }
            if (req.method === "POST") {
              const trigger = await createWorkflowTrigger(
                auth,
                parseCreateWorkflowTriggerBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.workflow_trigger.created", { id: trigger.id });
              return success(trigger, undefined, 201);
            }
            throw new ValidationError("GET or POST required for workflow-triggers");
};
