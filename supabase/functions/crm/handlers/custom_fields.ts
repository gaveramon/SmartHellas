import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createCustomField, listCustomFields } from "../service.ts";
import { CRM_ENTITY_TYPES, optionalEnumQuery, parseCreateCustomFieldBody } from "../validation.ts";

export const customFieldsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listCustomFields(
                  auth,
                  optionalEnumQuery(req, "applies_to", CRM_ENTITY_TYPES),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createCustomField(
                auth,
                parseCreateCustomFieldBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.custom_field.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for custom-fields");
};
