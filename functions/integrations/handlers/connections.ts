import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listTenantIntegrations } from "../service.ts";

export const connectionsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
            throw new ValidationError("GET required for connections");
          }
          return success(await listTenantIntegrations(auth));
};
