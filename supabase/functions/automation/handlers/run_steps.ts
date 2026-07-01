import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listRunSteps } from "../service.ts";
import { parseUuidQuery } from "../validation.ts";

export const runStepsHandler = async (ctx: HandlerContext) => {
  const { req, auth } = ctx;
  if (req.method !== "GET") {
    throw new ValidationError("GET required for run-steps");
  }
  return success(await listRunSteps(auth, parseUuidQuery(req, "run_id")));
};
