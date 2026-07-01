import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteWebhookDefinition, updateWebhookDefinition } from "../service.ts";
import { parseDeleteIdBody, parseUpdateWebhookBody } from "../validation.ts";

export const webhookDefinitionHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
            const updatedWebhook = await updateWebhookDefinition(
              auth,
              parseUpdateWebhookBody(await parseJsonBody(req)),
            );
            await logger.audit("integrations.webhook_definition.updated", {
              id: updatedWebhook.id,
            });
            return success(updatedWebhook);
          }
          if (req.method === "DELETE") {
            const deletedWebhook = await deleteWebhookDefinition(
              auth,
              parseDeleteIdBody(await parseJsonBody(req)),
            );
            await logger.audit("integrations.webhook_definition.deleted", deletedWebhook);
            return success(deletedWebhook);
          }
          throw new ValidationError("PATCH or DELETE required for webhook-definition");
};
