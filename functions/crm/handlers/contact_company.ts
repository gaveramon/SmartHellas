import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteContactCompany, updateContactCompany } from "../service.ts";
import { parseDeleteIdBody, parseUpdateContactCompanyBody } from "../validation.ts";

export const contactCompanyHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateContactCompany(
                auth,
                parseUpdateContactCompanyBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.contact_company.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteContactCompany(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.contact_company.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for contact-company");
};
