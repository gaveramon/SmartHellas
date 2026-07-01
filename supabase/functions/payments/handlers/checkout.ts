import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createCheckoutSession } from "../service.ts";

export const checkoutHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") throw new ValidationError("POST required for checkout");
  const session = await createCheckoutSession(auth, await parseJsonBody(req) as never);
  await logger.audit("payments.checkout.created", { id: session.id });
  return success(session, undefined, 201);
};
