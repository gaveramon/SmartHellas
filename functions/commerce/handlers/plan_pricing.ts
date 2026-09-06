import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createPlanPricing, listPlanPricing } from "../service.ts";
import { parseCreatePlanPricingBody, parseUuidQuery } from "../validation.ts";

export const planPricingHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listPlanPricing(auth, parseUuidQuery(req, "plan_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createPlanPricing(
                auth,
                parseCreatePlanPricingBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.plan_pricing.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for plan-pricing");
};
