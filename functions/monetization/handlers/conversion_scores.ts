import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listConversionScores } from "../service.ts";
import { optionalUuidQuery } from "../validation.ts";
import { parseLimitQuery } from "../validation.ts";

export const conversionScoresHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for conversion-scores");
            }
            return success(
              await listConversionScores(
                auth,
                optionalUuidQuery(req, "property_id"),
                parseLimitQuery(req, 50),
              ),
            );
};
