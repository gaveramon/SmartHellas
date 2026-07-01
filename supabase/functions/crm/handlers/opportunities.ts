import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createOpportunity, listOpportunities } from "../service.ts";
import { CRM_OPPORTUNITY_STATUSES, optionalEnumQuery, optionalUuidQuery, parseCreateOpportunityBody } from "../validation.ts";

export const opportunitiesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listOpportunities(
                  auth,
                  optionalUuidQuery(req, "pipeline_id"),
                  optionalUuidQuery(req, "stage_id"),
                  optionalEnumQuery(req, "status", CRM_OPPORTUNITY_STATUSES),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createOpportunity(
                auth,
                parseCreateOpportunityBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.opportunity.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for opportunities");
};
