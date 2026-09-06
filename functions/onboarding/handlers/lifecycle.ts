import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { getOnboardingLifecycle } from "../service.ts";
import { parseUuidQuery } from "../validation.ts";

export const lifecycleHandler = async (ctx: HandlerContext) => {
  const { req, auth } = ctx;
  if (req.method !== "GET") {
    throw new ValidationError("GET required for lifecycle");
  }
  return success(await getOnboardingLifecycle(auth, parseUuidQuery(req, "property_id")));
};
