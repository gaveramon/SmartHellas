import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteContact, getContact, updateContact } from "../service.ts";
import { parseDeleteIdBody, parseUpdateContactBody, parseUuidQuery } from "../validation.ts";

export const contactHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await getContact(auth, parseUuidQuery(req)));
            if (req.method === "PATCH") {
              const updated = await updateContact(auth, parseUpdateContactBody(await parseJsonBody(req)));
              await logger.audit("crm.contact.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteContact(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.contact.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for contact");
};
