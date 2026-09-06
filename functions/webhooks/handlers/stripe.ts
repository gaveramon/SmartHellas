import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { verifyStripeWebhookSignature } from "../../shared/stripe.ts";
import { readWebhookBody } from "../../shared/webhook.ts";
import { ingestWebhook } from "../service.ts";
import { parseStripeEvent } from "../validation.ts";

export const stripeHandler = async (ctx: HandlerContext) => {
  const { req, logger } = ctx;
  if (req.method !== "POST") {
    throw new ValidationError("POST required for stripe webhook");
  }

  const rawBody = await readWebhookBody(req);
  const signature = req.headers.get("Stripe-Signature");
  if (!signature || !(await verifyStripeWebhookSignature(rawBody, signature))) {
    throw new ValidationError("Invalid Stripe webhook signature");
  }

  const event = parseStripeEvent(JSON.parse(rawBody));
  const result = await ingestWebhook({
    source: "stripe",
    external_event_id: event.id,
    event_type: event.type,
    payload: event.payload,
    external_account_id: event.account,
  });

  await logger.audit("webhooks.stripe.ingested", {
    external_event_id: result.external_event_id,
    event_type: event.type,
  });
  return success(result, undefined, 202);
};
