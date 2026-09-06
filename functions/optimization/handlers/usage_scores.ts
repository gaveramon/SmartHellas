import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listDeviceUsageScores } from "../service.ts";
import { optionalUuidQuery } from "../validation.ts";

export const usageScoresHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for usage-scores");
            }
            return success(
              await listDeviceUsageScores(auth, optionalUuidQuery(req, "device_id")),
            );
};
