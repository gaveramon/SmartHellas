import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteShippingRule, updateShippingRule } from "../service.ts";
import { parseDeleteIdBody, parseUpdateShippingRuleBody } from "../validation.ts";

export const shippingRuleHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateShippingRule(
                auth,
                parseUpdateShippingRuleBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.shipping_rule.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteShippingRule(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.shipping_rule.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for shipping-rule");
};
