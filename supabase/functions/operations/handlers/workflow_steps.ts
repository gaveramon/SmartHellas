import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createWorkflowStep, listWorkflowSteps } from "../service.ts";
import { parseCreateWorkflowStepBody, parseUuidQuery } from "../validation.ts";

export const workflowStepsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listWorkflowSteps(auth, parseUuidQuery(req, "workflow_id")),
              );
            }
            if (req.method === "POST") {
              const step = await createWorkflowStep(
                auth,
                parseCreateWorkflowStepBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.workflow_step.created", { id: step.id });
              return success(step, undefined, 201);
            }
            throw new ValidationError("GET or POST required for workflow-steps");
};
