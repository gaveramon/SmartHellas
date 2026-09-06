import { withMethod } from "../core/index.ts";
import { switchTenant } from "../service.ts";
import { parseSwitchTenantBody } from "../validation.ts";
import { parseJsonBody, success } from "../../shared/response.ts";

export const switchTenantHandler = withMethod(["POST"], async (ctx) => {
  const switched = await switchTenant(
    ctx.auth,
    parseSwitchTenantBody(await parseJsonBody(ctx.req)),
  );
  await ctx.logger.audit("auth.tenant.switched", {
    tenant_id: switched.tenant_id,
    role: switched.role,
  });
  return success(switched);
}, "switch-tenant");
