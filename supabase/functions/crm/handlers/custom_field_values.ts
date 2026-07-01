import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { listCustomFieldValues, upsertCustomFieldValue } from "../service.ts";
import { CRM_ENTITY_TYPES, optionalEnumQuery, optionalUuidQuery, parseUpsertCustomFieldValueBody } from "../validation.ts";

export const customFieldValuesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listCustomFieldValues(
                  auth,
                  optionalEnumQuery(req, "entity_type", CRM_ENTITY_TYPES),
                  optionalUuidQuery(req, "entity_id"),
                  optionalUuidQuery(req, "custom_field_id"),
                ),
              );
            }
            if (req.method === "POST") {
              const upserted = await upsertCustomFieldValue(
                auth,
                parseUpsertCustomFieldValueBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.custom_field_value.upserted", { id: upserted.id });
              return success(upserted, undefined, 201);
            }
            throw new ValidationError("GET or POST required for custom-field-values");
};
