import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteFeatureFlag, updateFeatureFlag } from "../service.ts";
import { parseDeleteIdBody, parseUpdateFeatureFlagBody } from "../validation.ts";

export const featureFlagHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateFeatureFlag(
                auth,
                parseUpdateFeatureFlagBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.feature_flag.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteFeatureFlag(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.feature_flag.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for feature-flag");
};
