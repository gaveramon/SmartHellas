import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listCapabilities } from "../service.ts";
import { optionalCodeQuery } from "../validation.ts";

export const capabilitiesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
            throw new ValidationError("GET required for capabilities");
          }
          return success(
            await listCapabilities(auth, optionalCodeQuery(req, "provider_code")),
          );
};
