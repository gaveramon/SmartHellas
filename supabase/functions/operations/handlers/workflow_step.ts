import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteWorkflowStep, updateWorkflowStep } from "../service.ts";
import { parseDeleteIdBody, parseUpdateWorkflowStepBody } from "../validation.ts";

export const workflowStepHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const step = await updateWorkflowStep(
                auth,
                parseUpdateWorkflowStepBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.workflow_step.updated", { id: step.id });
              return success(step);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteWorkflowStep(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.workflow_step.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for workflow-step");
};
