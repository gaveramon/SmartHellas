import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listRecommendations } from "../service.ts";
import { optionalEnumQuery, optionalUuidQuery, RECOMMENDATION_STATUSES } from "../validation.ts";

export const recommendationsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for recommendations");
            }
            return success(
              await listRecommendations(
                auth,
                optionalEnumQuery(req, "status", RECOMMENDATION_STATUSES),
                optionalUuidQuery(req, "property_id"),
              ),
            );
};
