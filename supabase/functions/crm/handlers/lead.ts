import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteLead, getLead, updateLead } from "../service.ts";
import { parseDeleteIdBody, parseUpdateLeadBody, parseUuidQuery } from "../validation.ts";

export const leadHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await getLead(auth, parseUuidQuery(req)));
            if (req.method === "PATCH") {
              const updated = await updateLead(auth, parseUpdateLeadBody(await parseJsonBody(req)));
              await logger.audit("crm.lead.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteLead(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.lead.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for lead");
};
