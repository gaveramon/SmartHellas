import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteOnboardingBlueprint, getOnboardingBlueprintByCode, getOnboardingBlueprintById, updateOnboardingBlueprint } from "../service.ts";
import { optionalUuidQuery, parseCodeQuery, parseDeleteIdBody, parseUpdateBlueprintBody } from "../validation.ts";

export const blueprintHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const id = optionalUuidQuery(req, "id");
              if (id) {
                return success(await getOnboardingBlueprintById(auth, id));
              }
              return success(await getOnboardingBlueprintByCode(auth, parseCodeQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateOnboardingBlueprint(
                auth,
                parseUpdateBlueprintBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.blueprint.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteOnboardingBlueprint(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.blueprint.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for blueprint");
};
