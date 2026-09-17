import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteLogisticsTemplate, getLogisticsTemplate, updateLogisticsTemplate } from "../service.ts";
import { parseDeleteIdBody, parseUpdateLogisticsTemplateBody, parseUuidQuery } from "../validation.ts";

export const templateHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getLogisticsTemplate(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateLogisticsTemplate(
                auth,
                parseUpdateLogisticsTemplateBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.template.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteLogisticsTemplate(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.template.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for template");
};
