import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { getProvider } from "../service.ts";
import { parseCodeQuery } from "../validation.ts";

export const providerHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
            throw new ValidationError("GET required for provider");
          }
          return success(await getProvider(auth, parseCodeQuery(req)));
};
