import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteTask, getTask, updateTask } from "../service.ts";
import { parseDeleteIdBody, parseUpdateTaskBody, parseUuidQuery } from "../validation.ts";

export const taskHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await getTask(auth, parseUuidQuery(req)));
            if (req.method === "PATCH") {
              const updated = await updateTask(auth, parseUpdateTaskBody(await parseJsonBody(req)));
              await logger.audit("crm.task.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteTask(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.task.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for task");
};
