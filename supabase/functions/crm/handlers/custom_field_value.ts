import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteCustomFieldValue, updateCustomFieldValue } from "../service.ts";
import { parseDeleteIdBody, parseUpdateCustomFieldValueBody } from "../validation.ts";

export const customFieldValueHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateCustomFieldValue(
                auth,
                parseUpdateCustomFieldValueBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.custom_field_value.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteCustomFieldValue(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.custom_field_value.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for custom-field-value");
};
