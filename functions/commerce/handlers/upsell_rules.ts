import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createUpsellRule, listUpsellRules } from "../service.ts";
import { optionalEnumQuery, parseCreateUpsellRuleBody, UPSELL_PLAN_TRIGGERS } from "../validation.ts";

export const upsellRulesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listUpsellRules(
                  auth,
                  optionalEnumQuery(req, "trigger_event", UPSELL_PLAN_TRIGGERS),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createUpsellRule(
                auth,
                parseCreateUpsellRuleBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.upsell_rule.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for upsell-rules");
};
