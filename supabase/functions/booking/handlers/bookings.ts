import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createBooking, listBookings } from "../service.ts";
import { optionalUuidQuery, parseCreateBookingBody } from "../validation.ts";

export const bookingsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const propertyId = optionalUuidQuery(req, "property_id");
              return success(await listBookings(auth, propertyId));
            }
            if (req.method === "POST") {
              const booking = await createBooking(
                auth,
                parseCreateBookingBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.created", { id: booking.id });
              return success(booking, undefined, 201);
            }
            throw new ValidationError("GET or POST required for bookings");
};
