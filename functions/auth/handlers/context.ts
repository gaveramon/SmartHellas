import { withMethod } from "../core/index.ts";
import { getAuthContext } from "../service.ts";
import { success } from "../../shared/response.ts";

export const contextHandler = withMethod(["GET"], async (ctx) => {
  const context = await getAuthContext(ctx.auth);
  await ctx.logger.audit("auth.context.read");
  return success(context);
}, "context");
