import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createContactCompany, listContactCompanies } from "../service.ts";
import { optionalUuidQuery, parseCreateContactCompanyBody } from "../validation.ts";

export const contactCompaniesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listContactCompanies(
                  auth,
                  optionalUuidQuery(req, "contact_id"),
                  optionalUuidQuery(req, "company_id"),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createContactCompany(
                auth,
                parseCreateContactCompanyBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.contact_company.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for contact-companies");
};
