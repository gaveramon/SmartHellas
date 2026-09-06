import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listOnboardingLifecycleTransitions } from "../service.ts";
import { parseUuidQuery } from "../validation.ts";

export const lifecycleTransitionsHandler = async (ctx: HandlerContext) => {
  const { req, auth } = ctx;
  if (req.method !== "GET") {
    throw new ValidationError("GET required for lifecycle-transitions");
  }
  return success(
    await listOnboardingLifecycleTransitions(auth, parseUuidQuery(req, "property_id")),
  );
};
