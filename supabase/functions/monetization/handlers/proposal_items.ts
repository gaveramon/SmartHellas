import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createProposalItem, listProposalItems } from "../service.ts";
import { parseCreateProposalItemBody, parseUuidQuery } from "../validation.ts";

export const proposalItemsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listProposalItems(auth, parseUuidQuery(req, "proposal_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createProposalItem(
                auth,
                parseCreateProposalItemBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.proposal_item.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for proposal-items");
};
