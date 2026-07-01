import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteProductPlan, getProductPlan, updateProductPlan } from "../service.ts";
import { parseDeleteIdBody, parseUpdatePlanBody, parseUuidQuery } from "../validation.ts";

export const planHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getProductPlan(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateProductPlan(
                auth,
                parseUpdatePlanBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.plan.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteProductPlan(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.plan.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for plan");
};
