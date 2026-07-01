import { withMethod } from "../core/index.ts";
import { createTenant } from "../service.ts";
import { parseCreateTenantBody } from "../validation.ts";
import { parseJsonBody, success } from "../../shared/response.ts";

export const tenantCreateHandler = withMethod(["POST"], async (ctx) => {
  const created = await createTenant(
    ctx.auth,
    parseCreateTenantBody(await parseJsonBody(ctx.req)),
  );
  await ctx.logger.audit("auth.tenant.created", { tenant_id: created.id });
  return success(created, undefined, 201);
}, "tenant-create");
