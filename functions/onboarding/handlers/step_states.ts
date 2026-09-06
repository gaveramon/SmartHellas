import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listStepStates } from "../service.ts";
import { parseUuidQuery } from "../validation.ts";

export const stepStatesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listStepStates(auth, parseUuidQuery(req, "session_id")),
              );
            }
            throw new ValidationError("GET required for step-states");
};
