import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createTag, listTags } from "../service.ts";
import { parseCreateTagBody } from "../validation.ts";

export const tagsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await listTags(auth));
            if (req.method === "POST") {
              const created = await createTag(auth, parseCreateTagBody(await parseJsonBody(req)));
              await logger.audit("crm.tag.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for tags");
};
