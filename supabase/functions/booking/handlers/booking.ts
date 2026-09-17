import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteBooking, getBooking, updateBooking } from "../service.ts";
import { parseDeleteIdBody, parseUpdateBookingBody, parseUuidQuery } from "../validation.ts";

export const bookingHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getBooking(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateBooking(
                auth,
                parseUpdateBookingBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteBooking(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for booking");
};
