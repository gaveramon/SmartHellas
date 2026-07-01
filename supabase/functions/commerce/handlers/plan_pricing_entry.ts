import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deletePlanPricing, updatePlanPricing } from "../service.ts";
import { parseDeleteIdBody, parseUpdatePlanPricingBody } from "../validation.ts";

export const planPricingEntryHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updatePlanPricing(
                auth,
                parseUpdatePlanPricingBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.plan_pricing.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deletePlanPricing(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.plan_pricing.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for plan-pricing-entry");
};
