import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteFulfilmentOrder, getFulfilmentOrder, updateFulfilmentOrder } from "../service.ts";
import { parseDeleteIdBody, parseUpdateFulfilmentOrderBody, parseUuidQuery } from "../validation.ts";

export const fulfilmentOrderHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getFulfilmentOrder(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateFulfilmentOrder(
                auth,
                parseUpdateFulfilmentOrderBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.fulfilment_order.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteFulfilmentOrder(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.fulfilment_order.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for fulfilment-order");
};
