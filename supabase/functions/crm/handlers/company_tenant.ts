import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteCompanyTenant, updateCompanyTenant } from "../service.ts";
import { parseDeleteIdBody, parseUpdateCompanyTenantBody } from "../validation.ts";

export const companyTenantHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateCompanyTenant(
                auth,
                parseUpdateCompanyTenantBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.company_tenant.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteCompanyTenant(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.company_tenant.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for company-tenant");
};
