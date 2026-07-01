import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteSupportTicket, getSupportTicket, updateSupportTicket } from "../service.ts";
import { parseDeleteIdBody, parseUpdateSupportTicketBody, parseUuidQuery } from "../validation.ts";

export const supportTicketHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getSupportTicket(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const ticket = await updateSupportTicket(
                auth,
                parseUpdateSupportTicketBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.support_ticket.updated", { id: ticket.id });
              return success(ticket);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteSupportTicket(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.support_ticket.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for support-ticket");
};
