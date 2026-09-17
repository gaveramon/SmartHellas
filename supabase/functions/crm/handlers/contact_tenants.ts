import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createContactTenant, listContactTenants } from "../service.ts";
import { optionalUuidQuery, parseCreateContactTenantBody } from "../validation.ts";

export const contactTenantsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listContactTenants(auth, optionalUuidQuery(req, "contact_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createContactTenant(
                auth,
                parseCreateContactTenantBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.contact_tenant.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for contact-tenants");
};
