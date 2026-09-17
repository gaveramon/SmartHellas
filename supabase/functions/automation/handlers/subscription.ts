import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteSubscription } from "../service.ts";
import { parseDeleteSubscriptionBody } from "../validation.ts";

export const subscriptionHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "DELETE") {
    throw new ValidationError("DELETE required for subscription");
  }
  const deleted = await deleteSubscription(
    auth,
    parseDeleteSubscriptionBody(await parseJsonBody(req)),
  );
  await logger.audit("automation.subscription.deleted", deleted);
  return success(deleted);
};
