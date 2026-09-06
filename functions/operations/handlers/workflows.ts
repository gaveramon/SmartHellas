import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createWorkflow, listWorkflows } from "../service.ts";
import { parseCreateWorkflowBody } from "../validation.ts";

export const workflowsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listWorkflows(auth));
            }
            if (req.method === "POST") {
              const workflow = await createWorkflow(
                auth,
                parseCreateWorkflowBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.workflow.created", { id: workflow.id });
              return success(workflow, undefined, 201);
            }
            throw new ValidationError("GET or POST required for workflows");
};
