import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createInteraction, listInteractions } from "../service.ts";
import { optionalUuidQuery, parseCreateInteractionBody } from "../validation.ts";
import { parseLimitQuery } from "../validation.ts";

export const interactionsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listInteractions(
                  auth,
                  optionalUuidQuery(req, "contact_id"),
                  optionalUuidQuery(req, "lead_id"),
                  optionalUuidQuery(req, "opportunity_id"),
                  optionalUuidQuery(req, "company_id"),
                  parseLimitQuery(req),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createInteraction(
                auth,
                parseCreateInteractionBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.interaction.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for interactions");
};
