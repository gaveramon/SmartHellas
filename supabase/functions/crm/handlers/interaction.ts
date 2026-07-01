import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { softDeleteInteraction } from "../service.ts";
import { parseSoftDeleteInteractionBody } from "../validation.ts";

export const interactionHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const deleted = await softDeleteInteraction(
                auth,
                parseSoftDeleteInteractionBody(await parseJsonBody(req)).id,
              );
              await logger.audit("crm.interaction.soft_deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH required for interaction (soft delete only)");
};
