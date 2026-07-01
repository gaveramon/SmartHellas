import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createFeatureFlag, listFeatureFlags } from "../service.ts";
import { parseCreateFeatureFlagBody } from "../validation.ts";

export const featureFlagsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listFeatureFlags(auth));
            }
            if (req.method === "POST") {
              const created = await createFeatureFlag(
                auth,
                parseCreateFeatureFlagBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.feature_flag.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for feature-flags");
};
