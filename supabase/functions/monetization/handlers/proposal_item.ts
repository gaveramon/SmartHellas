import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteProposalItem, updateProposalItem } from "../service.ts";
import { parseDeleteIdBody, parseUpdateProposalItemBody } from "../validation.ts";

export const proposalItemHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateProposalItem(
                auth,
                parseUpdateProposalItemBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.proposal_item.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteProposalItem(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.proposal_item.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for proposal-item");
};
