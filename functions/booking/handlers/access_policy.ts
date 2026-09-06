import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteAccessPolicy, updateAccessPolicy } from "../service.ts";
import { parseDeleteIdBody, parseUpdateAccessPolicyBody } from "../validation.ts";

export const accessPolicyHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateAccessPolicy(
                auth,
                parseUpdateAccessPolicyBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.access_policy.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteAccessPolicy(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.access_policy.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for access-policy");
};
