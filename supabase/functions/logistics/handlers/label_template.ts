import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteLabelTemplate, updateLabelTemplate } from "../service.ts";
import { parseDeleteIdBody, parseUpdateLabelTemplateBody } from "../validation.ts";

export const labelTemplateHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateLabelTemplate(
                auth,
                parseUpdateLabelTemplateBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.label_template.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteLabelTemplate(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.label_template.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for label-template");
};
