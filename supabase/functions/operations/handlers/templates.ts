import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createTemplate, listTemplates } from "../service.ts";
import { parseCreateTemplateBody } from "../validation.ts";

export const templatesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listTemplates(auth));
            }
            if (req.method === "POST") {
              const created = await createTemplate(
                auth,
                parseCreateTemplateBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.template.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for templates");
};
