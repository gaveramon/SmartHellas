import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listInsightEvents } from "../service.ts";
import { OPTIMIZATION_INSIGHT_TYPES, optionalEnumQuery, optionalUuidQuery } from "../validation.ts";

export const insightsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for insights");
            }
            return success(
              await listInsightEvents(
                auth,
                optionalUuidQuery(req, "property_id"),
                optionalEnumQuery(req, "insight_type", OPTIMIZATION_INSIGHT_TYPES),
              ),
            );
};
