import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteWorkflow, getWorkflow, updateWorkflow } from "../service.ts";
import { parseDeleteIdBody, parseUpdateWorkflowBody, parseUuidQuery } from "../validation.ts";

export const workflowHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getWorkflow(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const workflow = await updateWorkflow(
                auth,
                parseUpdateWorkflowBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.workflow.updated", { id: workflow.id });
              return success(workflow);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteWorkflow(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("operations.workflow.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for workflow");
};
