import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createLabelTemplate, listLabelTemplates } from "../service.ts";
import { optionalUuidQuery, parseCreateLabelTemplateBody } from "../validation.ts";

export const labelTemplatesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listLabelTemplates(auth, optionalUuidQuery(req, "carrier_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createLabelTemplate(
                auth,
                parseCreateLabelTemplateBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.label_template.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for label-templates");
};
