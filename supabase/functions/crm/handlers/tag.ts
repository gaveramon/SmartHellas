import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteTag, updateTag } from "../service.ts";
import { parseDeleteIdBody, parseUpdateTagBody } from "../validation.ts";

export const tagHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateTag(auth, parseUpdateTagBody(await parseJsonBody(req)));
              await logger.audit("crm.tag.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteTag(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.tag.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for tag");
};
