import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteTagAssignment } from "../service.ts";
import { parseDeleteIdBody } from "../validation.ts";

export const tagAssignmentHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "DELETE") {
              const deleted = await deleteTagAssignment(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.tag_assignment.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("DELETE required for tag-assignment");
};
