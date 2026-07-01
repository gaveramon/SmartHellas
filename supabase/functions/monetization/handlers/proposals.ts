import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createProposal, listProposals } from "../service.ts";
import { optionalEnumQuery, optionalUuidQuery, parseCreateProposalBody, PROPOSAL_STATUSES } from "../validation.ts";

export const proposalsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listProposals(
                  auth,
                  optionalEnumQuery(req, "status", PROPOSAL_STATUSES),
                  optionalUuidQuery(req, "property_id"),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createProposal(
                auth,
                parseCreateProposalBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.proposal.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for proposals");
};
