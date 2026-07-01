import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createShippingRule, listShippingRules } from "../service.ts";
import { parseCreateShippingRuleBody } from "../validation.ts";

export const shippingRulesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listShippingRules(auth));
            }
            if (req.method === "POST") {
              const created = await createShippingRule(
                auth,
                parseCreateShippingRuleBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.shipping_rule.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for shipping-rules");
};
