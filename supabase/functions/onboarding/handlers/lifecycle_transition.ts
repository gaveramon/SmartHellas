import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { transitionOnboardingLifecycle } from "../service.ts";
import { parseLifecycleTransitionBody } from "../validation.ts";

export const lifecycleTransitionHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
    throw new ValidationError("POST required for lifecycle-transition");
  }
  const input = parseLifecycleTransitionBody(await parseJsonBody(req));
  const lifecycle = await transitionOnboardingLifecycle(auth, input);
  await logger.audit("onboarding.lifecycle.transitioned", {
    property_id: input.property_id,
    to_state: input.to_state,
  });
  return success(lifecycle);
};
