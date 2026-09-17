import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createContact, listContacts } from "../service.ts";
import { CRM_CONTACT_STATUSES, optionalEnumQuery, parseCreateContactBody } from "../validation.ts";

export const contactsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listContacts(
                  auth,
                  optionalEnumQuery(req, "status", CRM_CONTACT_STATUSES),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createContact(auth, parseCreateContactBody(await parseJsonBody(req)));
              await logger.audit("crm.contact.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for contacts");
};
