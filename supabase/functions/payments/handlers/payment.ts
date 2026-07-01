import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { cancelPayment, getPayment } from "../service.ts";

export const paymentHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
    const id = new URL(req.url).searchParams.get("id");
    if (!id) throw new ValidationError("id query parameter required");
    return success(await getPayment(auth, id));
  }
  if (req.method === "DELETE") {
    const cancelled = await cancelPayment(auth, await parseJsonBody(req) as never);
    await logger.audit("payments.cancelled", { id: cancelled.id });
    return success(cancelled);
  }
  throw new ValidationError("GET or DELETE required for payment");
};
