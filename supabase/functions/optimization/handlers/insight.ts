import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { getInsightEvent } from "../service.ts";
import { parseUuidQuery } from "../validation.ts";

export const insightHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for insight");
            }
            return success(await getInsightEvent(auth, parseUuidQuery(req)));
};
