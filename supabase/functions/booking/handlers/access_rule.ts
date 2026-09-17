import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteAccessRule, updateAccessRule } from "../service.ts";
import { parseDeleteIdBody, parseUpdateAccessRuleBody } from "../validation.ts";

export const accessRuleHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateAccessRule(
                auth,
                parseUpdateAccessRuleBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.access_rule.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteAccessRule(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.access_rule.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for access-rule");
};
