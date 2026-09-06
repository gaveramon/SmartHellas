import { dispatchMethod } from "../core/index.ts";
import { getCurrentTenant, updateTenant } from "../service.ts";
import { parseUpdateTenantBody } from "../validation.ts";
import { parseJsonBody, success } from "../../shared/response.ts";

export const tenantHandler = dispatchMethod(
  {
    GET: async (ctx) => {
      const tenant = await getCurrentTenant(ctx.auth);
      return success(tenant);
    },
    PATCH: async (ctx) => {
      const updated = await updateTenant(
        ctx.auth,
        parseUpdateTenantBody(await parseJsonBody(ctx.req)),
      );
      await ctx.logger.audit("auth.tenant.updated");
      return success(updated);
    },
  },
  "tenant",
);
