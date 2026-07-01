import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteOnboardingSession, getOnboardingSession, updateOnboardingSession } from "../service.ts";
import { parseDeleteIdBody, parseUpdateSessionBody, parseUuidQuery } from "../validation.ts";

export const sessionHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getOnboardingSession(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateOnboardingSession(
                auth,
                parseUpdateSessionBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.session.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteOnboardingSession(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.session.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for session");
};
