import { withMethod } from "../core/index.ts";
import { listUserTenants } from "../service.ts";
import { success } from "../../shared/response.ts";

export const tenantsHandler = withMethod(["GET"], async (ctx) => {
  const tenants = await listUserTenants(ctx.auth);
  await ctx.logger.audit("auth.tenants.list", { count: tenants.length });
  return success(tenants);
}, "tenants");
