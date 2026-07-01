import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createTagAssignment, listTagAssignments } from "../service.ts";
import { CRM_ENTITY_TYPES, optionalEnumQuery, optionalUuidQuery, parseCreateTagAssignmentBody } from "../validation.ts";

export const tagAssignmentsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listTagAssignments(
                  auth,
                  optionalEnumQuery(req, "entity_type", CRM_ENTITY_TYPES),
                  optionalUuidQuery(req, "entity_id"),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createTagAssignment(
                auth,
                parseCreateTagAssignmentBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.tag_assignment.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for tag-assignments");
};
