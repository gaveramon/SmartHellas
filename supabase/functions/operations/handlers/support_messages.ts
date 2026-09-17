import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createSupportMessage, listSupportMessages } from "../service.ts";
import { parseCreateSupportMessageBody, parseUuidQuery } from "../validation.ts";

export const supportMessagesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listSupportMessages(auth, parseUuidQuery(req, "ticket_id")),
              );
            }
            if (req.method === "POST") {
              const message = await createSupportMessage(
                auth,
                parseCreateSupportMessageBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.support_message.created", { id: message.id });
              return success(message, undefined, 201);
            }
            throw new ValidationError("GET or POST required for support-messages");
};
