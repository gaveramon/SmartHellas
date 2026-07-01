import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteCompany, getCompany, updateCompany } from "../service.ts";
import { parseDeleteIdBody, parseUpdateCompanyBody, parseUuidQuery } from "../validation.ts";

export const companyHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await getCompany(auth, parseUuidQuery(req)));
            if (req.method === "PATCH") {
              const updated = await updateCompany(auth, parseUpdateCompanyBody(await parseJsonBody(req)));
              await logger.audit("crm.company.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteCompany(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.company.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for company");
};
