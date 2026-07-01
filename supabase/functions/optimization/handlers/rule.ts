import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteOptimizationRule, getOptimizationRule, updateOptimizationRule } from "../service.ts";
import { parseDeleteIdBody, parseUpdateRuleBody, parseUuidQuery } from "../validation.ts";

export const ruleHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getOptimizationRule(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateOptimizationRule(
                auth,
                parseUpdateRuleBody(await parseJsonBody(req)),
              );
              await logger.audit("optimization.rule.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteOptimizationRule(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("optimization.rule.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for rule");
};
