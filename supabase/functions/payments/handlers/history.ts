import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { paymentHistory } from "../service.ts";

export const historyHandler = async (ctx: HandlerContext) => {
  const { req, auth } = ctx;
  if (req.method !== "GET") throw new ValidationError("GET required for history");
  const paymentIntentId = new URL(req.url).searchParams.get("payment_intent_id");
  if (!paymentIntentId) throw new ValidationError("payment_intent_id query parameter required");
  return success(await paymentHistory(auth, paymentIntentId));
};
