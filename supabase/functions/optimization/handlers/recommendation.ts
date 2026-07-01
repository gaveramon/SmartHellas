import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteRecommendation, getRecommendation, updateRecommendation } from "../service.ts";
import { parseDeleteIdBody, parseUpdateRecommendationBody, parseUuidQuery } from "../validation.ts";

export const recommendationHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getRecommendation(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateRecommendation(
                auth,
                parseUpdateRecommendationBody(await parseJsonBody(req)),
              );
              await logger.audit("optimization.recommendation.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteRecommendation(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("optimization.recommendation.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for recommendation");
};
