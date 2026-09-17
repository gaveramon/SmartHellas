import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createCompanyTenant, listCompanyTenants } from "../service.ts";
import { optionalUuidQuery, parseCreateCompanyTenantBody } from "../validation.ts";

export const companyTenantsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listCompanyTenants(auth, optionalUuidQuery(req, "company_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createCompanyTenant(
                auth,
                parseCreateCompanyTenantBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.company_tenant.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for company-tenants");
};
