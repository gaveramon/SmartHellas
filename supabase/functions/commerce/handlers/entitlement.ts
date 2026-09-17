import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteFeatureEntitlement, updateFeatureEntitlement } from "../service.ts";
import { parseDeleteIdBody, parseUpdateEntitlementBody } from "../validation.ts";

export const entitlementHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateFeatureEntitlement(
                auth,
                parseUpdateEntitlementBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.entitlement.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteFeatureEntitlement(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.entitlement.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for entitlement");
};
