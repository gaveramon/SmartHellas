import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { getPortalBootstrap } from "../service.ts";

export const bootstrapHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for bootstrap");
            }
            return success(await getPortalBootstrap(auth));
};
