import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteChecklistItem, updateChecklistItem } from "../service.ts";
import { parseDeleteIdBody, parseUpdateChecklistBody } from "../validation.ts";

export const checklistItemHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateChecklistItem(
                auth,
                parseUpdateChecklistBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.checklist.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteChecklistItem(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.checklist.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for checklist-item");
};
