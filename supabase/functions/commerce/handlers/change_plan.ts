import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { changeTenantPlan } from "../service.ts";
import { parseChangePlanBody } from "../validation.ts";

export const changePlanHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
              throw new ValidationError("POST required for change-plan");
            }
            const changed = await changeTenantPlan(auth, parseChangePlanBody(await parseJsonBody(req)));
            await logger.audit(
              "commerce.plan_changed",
              { ...(changed as unknown as Record<string, unknown>) },
            );
            return success(changed);
};
