import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteCustomField, updateCustomField } from "../service.ts";
import { parseDeleteIdBody, parseUpdateCustomFieldBody } from "../validation.ts";

export const customFieldHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateCustomField(
                auth,
                parseUpdateCustomFieldBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.custom_field.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteCustomField(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.custom_field.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for custom-field");
};
