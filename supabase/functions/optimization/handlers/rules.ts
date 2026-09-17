import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createOptimizationRule, listOptimizationRules } from "../service.ts";
import { parseCreateRuleBody } from "../validation.ts";

export const rulesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listOptimizationRules(auth));
            }
            if (req.method === "POST") {
              const created = await createOptimizationRule(
                auth,
                parseCreateRuleBody(await parseJsonBody(req)),
              );
              await logger.audit("optimization.rule.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for rules");
};
