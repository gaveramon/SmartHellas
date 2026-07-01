import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listCredentials } from "../service.ts";
import { optionalUuidQuery } from "../validation.ts";

export const credentialsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for credentials");
            }
            const bookingId = optionalUuidQuery(req, "booking_id");
            return success(await listCredentials(auth, bookingId));
};
