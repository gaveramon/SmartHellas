import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createLead, listLeads } from "../service.ts";
import { CRM_LEAD_STATUSES, optionalEnumQuery, optionalUuidQuery, parseCreateLeadBody } from "../validation.ts";

export const leadsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listLeads(
                  auth,
                  optionalEnumQuery(req, "status", CRM_LEAD_STATUSES),
                  optionalUuidQuery(req, "campaign_id"),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createLead(auth, parseCreateLeadBody(await parseJsonBody(req)));
              await logger.audit("crm.lead.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for leads");
};
