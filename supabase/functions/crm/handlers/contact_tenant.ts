import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteContactTenant, updateContactTenant } from "../service.ts";
import { parseDeleteIdBody, parseUpdateContactTenantBody } from "../validation.ts";

export const contactTenantHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateContactTenant(
                auth,
                parseUpdateContactTenantBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.contact_tenant.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteContactTenant(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.contact_tenant.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for contact-tenant");
};
