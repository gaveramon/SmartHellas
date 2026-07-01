import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createOnboardingBlueprint, listOnboardingBlueprints } from "../service.ts";
import { optionalEnumQuery, parseActiveOnlyQuery, parseCreateBlueprintBody, PROPERTY_TYPES } from "../validation.ts";

export const blueprintsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listOnboardingBlueprints(
                  auth,
                  optionalEnumQuery(req, "property_type", PROPERTY_TYPES),
                  req.url.includes("active_only=") ? parseActiveOnlyQuery(req) : true,
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createOnboardingBlueprint(
                auth,
                parseCreateBlueprintBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.blueprint.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for blueprints");
};
