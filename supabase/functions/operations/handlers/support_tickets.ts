import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createSupportTicket, listSupportTickets } from "../service.ts";
import { optionalEnumQuery, parseCreateSupportTicketBody, PRIORITY_LEVELS, SUPPORT_TICKET_STATUSES } from "../validation.ts";

export const supportTicketsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listSupportTickets(
                  auth,
                  optionalEnumQuery(req, "status", SUPPORT_TICKET_STATUSES),
                  optionalEnumQuery(req, "priority", PRIORITY_LEVELS),
                ),
              );
            }
            if (req.method === "POST") {
              const ticket = await createSupportTicket(
                auth,
                parseCreateSupportTicketBody(await parseJsonBody(req)),
              );
              await logger.audit("operations.support_ticket.created", { id: ticket.id });
              return success(ticket, undefined, 201);
            }
            throw new ValidationError("GET or POST required for support-tickets");
};
