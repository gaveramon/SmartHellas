import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createBookingAccess, deleteBookingAccess, getBookingAccess } from "../service.ts";
import { parseCreateBookingAccessBody, parseDeleteIdBody, parseUuidQuery } from "../validation.ts";

export const bookingAccessHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const bookingId = parseUuidQuery(req, "booking_id");
              return success(await getBookingAccess(auth, bookingId));
            }
            if (req.method === "POST") {
              const access = await createBookingAccess(
                auth,
                parseCreateBookingAccessBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.access.created", { booking_id: access.booking_id });
              return success(access, undefined, 201);
            }
            if (req.method === "DELETE") {
              const bookingId = parseDeleteIdBody(await parseJsonBody(req), "booking_id");
              const deleted = await deleteBookingAccess(auth, bookingId);
              await logger.audit("booking.access.deleted", { booking_id: bookingId });
              return success(deleted);
            }
            throw new ValidationError("GET, POST, or DELETE required for booking-access");
};
