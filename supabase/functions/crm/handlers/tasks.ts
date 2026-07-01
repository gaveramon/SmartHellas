import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createTask, listTasks } from "../service.ts";
import { CRM_TASK_STATUSES, CRM_TASK_TARGET_TYPES, optionalEnumQuery, optionalUuidQuery, parseCreateTaskBody } from "../validation.ts";

export const tasksHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listTasks(
                  auth,
                  optionalEnumQuery(req, "target_type", CRM_TASK_TARGET_TYPES),
                  optionalUuidQuery(req, "target_id"),
                  optionalEnumQuery(req, "status", CRM_TASK_STATUSES),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createTask(auth, parseCreateTaskBody(await parseJsonBody(req)));
              await logger.audit("crm.task.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for tasks");
};
