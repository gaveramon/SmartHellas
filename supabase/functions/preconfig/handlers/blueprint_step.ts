import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteBlueprintStep, updateBlueprintStep } from "../service.ts";
import { parseDeleteIdBody, parseUpdateBlueprintStepBody } from "../validation.ts";

export const blueprintStepHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateBlueprintStep(
                auth,
                parseUpdateBlueprintStepBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.blueprint_step.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteBlueprintStep(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.blueprint_step.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for blueprint-step");
};
