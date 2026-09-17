import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { listSubscriptions, upsertSubscription } from "../service.ts";
import { optionalUuidQuery, parseUpsertSubscriptionBody } from "../validation.ts";

export const subscriptionsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
    return success(
      await listSubscriptions(auth, optionalUuidQuery(req, "workflow_id")),
    );
  }
  if (req.method === "POST") {
    const subscription = await upsertSubscription(
      auth,
      parseUpsertSubscriptionBody(await parseJsonBody(req)),
    );
    await logger.audit("automation.subscription.upserted", { id: subscription.id });
    return success(subscription, undefined, 201);
  }
  throw new ValidationError("GET or POST required for subscriptions");
};
