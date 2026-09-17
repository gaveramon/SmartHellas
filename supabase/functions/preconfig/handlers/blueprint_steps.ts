import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createBlueprintStep, listBlueprintSteps } from "../service.ts";
import { parseCreateBlueprintStepBody, parseUuidQuery } from "../validation.ts";

export const blueprintStepsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listBlueprintSteps(auth, parseUuidQuery(req, "blueprint_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createBlueprintStep(
                auth,
                parseCreateBlueprintStepBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.blueprint_step.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for blueprint-steps");
};
