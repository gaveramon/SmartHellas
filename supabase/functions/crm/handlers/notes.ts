import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createNote, listNotes } from "../service.ts";
import { CRM_ENTITY_TYPES, optionalEnumQuery, parseCreateNoteBody, parseUuidQuery } from "../validation.ts";

export const notesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const entityType = optionalEnumQuery(req, "entity_type", CRM_ENTITY_TYPES);
              if (!entityType) {
                throw new ValidationError("entity_type query param is required");
              }
              return success(
                await listNotes(auth, entityType, parseUuidQuery(req, "entity_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createNote(auth, parseCreateNoteBody(await parseJsonBody(req)));
              await logger.audit("crm.note.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for notes");
};
