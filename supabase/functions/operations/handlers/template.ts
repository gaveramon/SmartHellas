import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteTemplate, getTemplate, updateTemplate } from "../service.ts";
import { parseDeleteIdBody, parseUpdateTemplateBody, parseUuidQuery } from "../validation.ts";

export const templateHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getTemplate(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateTemplate(
                auth,
                parseUpdateTemplateBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.template.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteTemplate(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("operations.template.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for template");
};
