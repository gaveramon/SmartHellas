import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createOnboardingSession, listOnboardingSessions } from "../service.ts";
import { optionalUuidQuery, parseCreateSessionBody } from "../validation.ts";

export const sessionsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listOnboardingSessions(auth, optionalUuidQuery(req, "property_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createOnboardingSession(
                auth,
                parseCreateSessionBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.session.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for sessions");
};
