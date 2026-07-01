import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteUpsellRule, updateUpsellRule } from "../service.ts";
import { parseDeleteIdBody, parseUpdateUpsellRuleBody } from "../validation.ts";

export const upsellRuleHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateUpsellRule(
                auth,
                parseUpdateUpsellRuleBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.upsell_rule.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteUpsellRule(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.upsell_rule.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for upsell-rule");
};
