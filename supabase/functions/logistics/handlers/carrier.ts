import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteCarrier, getCarrier, updateCarrier } from "../service.ts";
import { parseDeleteIdBody, parseUpdateCarrierBody, parseUuidQuery } from "../validation.ts";

export const carrierHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getCarrier(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateCarrier(
                auth,
                parseUpdateCarrierBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.carrier.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteCarrier(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("logistics.carrier.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for carrier");
};
