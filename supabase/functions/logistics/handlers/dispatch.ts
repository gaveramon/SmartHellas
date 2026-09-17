import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { dispatchFulfilmentOrder } from "../service.ts";
import { parseDispatchFulfilmentBody } from "../validation.ts";

export const dispatchHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
              throw new ValidationError("POST required for dispatch");
            }
            const dispatched = await dispatchFulfilmentOrder(
              auth,
              parseDispatchFulfilmentBody(await parseJsonBody(req)),
            );
            await logger.audit("logistics.fulfilment_order.dispatch_queued", {
              ...(dispatched as unknown as Record<string, unknown>),
            });
            return success(dispatched, undefined, 202);
};
