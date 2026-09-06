import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createCompany, listCompanies } from "../service.ts";
import { parseCreateCompanyBody } from "../validation.ts";

export const companiesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await listCompanies(auth));
            if (req.method === "POST") {
              const created = await createCompany(auth, parseCreateCompanyBody(await parseJsonBody(req)));
              await logger.audit("crm.company.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for companies");
};
