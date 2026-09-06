import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteTemplate, updateTemplate } from "../service.ts";

export const templateHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
    const updated = await updateTemplate(auth, await parseJsonBody(req) as Record<string, unknown>);
    await logger.audit("notifications.template.updated", { id: updated.id });
    return success(updated);
  }
  if (req.method === "DELETE") {
    const body = await parseJsonBody(req) as { id: string };
    const deleted = await deleteTemplate(auth, body.id);
    await logger.audit("notifications.template.deleted", deleted);
    return success(deleted);
  }
  throw new ValidationError("PATCH or DELETE required for template");
};
