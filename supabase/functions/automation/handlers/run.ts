import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { cancelRun, getRun } from "../service.ts";
import { parseCancelRunBody, parseUuidQuery } from "../validation.ts";

export const runHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
    return success(await getRun(auth, parseUuidQuery(req)));
  }
  if (req.method === "DELETE") {
    const cancelled = await cancelRun(auth, parseCancelRunBody(await parseJsonBody(req)));
    await logger.audit("automation.run.cancelled", { id: cancelled.id });
    return success(cancelled);
  }
  throw new ValidationError("GET or DELETE required for run");
};
