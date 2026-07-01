import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { getCredential } from "../service.ts";
import { parseUuidQuery } from "../validation.ts";

export const credentialHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for credential");
            }
            return success(await getCredential(auth, parseUuidQuery(req)));
};
