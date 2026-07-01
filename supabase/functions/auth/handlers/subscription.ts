import { dispatchMethod } from "../core/index.ts";
import { getSubscription, updateSubscription } from "../service.ts";
import { parseUpdateSubscriptionBody } from "../validation.ts";
import { parseJsonBody, success } from "../../shared/response.ts";

export const subscriptionHandler = dispatchMethod(
  {
    GET: async (ctx) => {
      const sub = await getSubscription(ctx.auth);
      return success(sub);
    },
    PATCH: async (ctx) => {
      const updatedSub = await updateSubscription(
        ctx.auth,
        parseUpdateSubscriptionBody(await parseJsonBody(ctx.req)),
      );
      await ctx.logger.audit("auth.subscription.updated", {
        subscription_id: updatedSub.id,
      });
      return success(updatedSub);
    },
  },
  "subscription",
);
