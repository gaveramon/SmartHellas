import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteProposal, getProposal, updateProposal } from "../service.ts";
import { parseDeleteIdBody, parseUpdateProposalBody, parseUuidQuery } from "../validation.ts";

export const proposalHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getProposal(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateProposal(
                auth,
                parseUpdateProposalBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.proposal.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteProposal(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.proposal.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for proposal");
};
