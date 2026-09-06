import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { updateStepState } from "../service.ts";
import { parseUpdateStepStateBody } from "../validation.ts";

export const stepStateHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateStepState(
                auth,
                parseUpdateStepStateBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.step_state.updated", { id: updated.id });
              return success(updated);
            }
            throw new ValidationError("PATCH required for step-state");
};
