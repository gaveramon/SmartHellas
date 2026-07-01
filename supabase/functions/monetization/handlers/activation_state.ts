import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listActivationState } from "../service.ts";
import { optionalEnumQuery, optionalUuidQuery, SERVICE_TYPES } from "../validation.ts";

export const activationStateHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for activation-state");
            }
            return success(
              await listActivationState(
                auth,
                optionalUuidQuery(req, "property_id"),
                optionalEnumQuery(req, "service_type", SERVICE_TYPES),
              ),
            );
};
