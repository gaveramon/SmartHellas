import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createAccessRule, listAccessRules } from "../service.ts";
import { optionalUuidQuery, parseCreateAccessRuleBody } from "../validation.ts";

export const accessRulesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const propertyId = optionalUuidQuery(req, "property_id");
              return success(await listAccessRules(auth, propertyId));
            }
            if (req.method === "POST") {
              const rule = await createAccessRule(
                auth,
                parseCreateAccessRuleBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.access_rule.created", { id: rule.id });
              return success(rule, undefined, 201);
            }
            throw new ValidationError("GET or POST required for access-rules");
};
