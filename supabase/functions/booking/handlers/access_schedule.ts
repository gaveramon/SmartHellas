import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { getAccessSchedule, upsertAccessSchedule } from "../service.ts";
import { parseUpsertAccessScheduleBody, parseUuidQuery } from "../validation.ts";

export const accessScheduleHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const propertyId = parseUuidQuery(req, "property_id");
              return success(await getAccessSchedule(auth, propertyId));
            }
            if (req.method === "PUT" || req.method === "POST") {
              const schedule = await upsertAccessSchedule(
                auth,
                parseUpsertAccessScheduleBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.access_schedule.upserted", {
                property_id: schedule.property_id,
              });
              return success(schedule);
            }
            throw new ValidationError("GET or PUT/POST required for access-schedule");
};
