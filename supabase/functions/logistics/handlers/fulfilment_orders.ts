import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createFulfilmentOrder, listFulfilmentOrders } from "../service.ts";
import { FULFILMENT_STATUSES, optionalEnumQuery, optionalUuidQuery, parseCreateFulfilmentOrderBody } from "../validation.ts";

export const fulfilmentOrdersHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listFulfilmentOrders(
                  auth,
                  optionalEnumQuery(req, "status", FULFILMENT_STATUSES),
                  optionalUuidQuery(req, "property_id"),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createFulfilmentOrder(
                auth,
                parseCreateFulfilmentOrderBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.fulfilment_order.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for fulfilment-orders");
};
