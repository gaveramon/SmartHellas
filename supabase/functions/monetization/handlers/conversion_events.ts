import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listConversionEvents } from "../service.ts";
import { CONVERSION_EVENT_TYPES, optionalEnumQuery, optionalUuidQuery } from "../validation.ts";
import { parseLimitQuery } from "../validation.ts";

export const conversionEventsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for conversion-events");
            }
            return success(
              await listConversionEvents(
                auth,
                optionalUuidQuery(req, "proposal_id"),
                optionalEnumQuery(req, "event_type", CONVERSION_EVENT_TYPES),
                parseLimitQuery(req),
              ),
            );
};
