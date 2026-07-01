import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteOpportunity, getOpportunity, updateOpportunity } from "../service.ts";
import { parseDeleteIdBody, parseUpdateOpportunityBody, parseUuidQuery } from "../validation.ts";

export const opportunityHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getOpportunity(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateOpportunity(
                auth,
                parseUpdateOpportunityBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.opportunity.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteOpportunity(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.opportunity.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for opportunity");
};
