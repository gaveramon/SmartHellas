import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteWorkflowTrigger, updateWorkflowTrigger } from "../service.ts";
import { parseDeleteIdBody, parseUpdateWorkflowTriggerBody } from "../validation.ts";

export const workflowTriggerHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const trigger = await updateWorkflowTrigger(
                auth,
                parseUpdateWorkflowTriggerBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.workflow_trigger.updated", { id: trigger.id });
              return success(trigger);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteWorkflowTrigger(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.workflow_trigger.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for workflow-trigger");
};
