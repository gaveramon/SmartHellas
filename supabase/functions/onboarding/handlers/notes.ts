import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createNote, listNotes } from "../service.ts";
import { parseCreateNoteBody, parseUuidQuery } from "../validation.ts";

export const notesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listNotes(auth, parseUuidQuery(req, "session_id")));
            }
            if (req.method === "POST") {
              const note = await createNote(auth, parseCreateNoteBody(await parseJsonBody(req)));
              await logger.audit("onboarding.note.created", { id: note.id });
              return success(note, undefined, 201);
            }
            throw new ValidationError("GET or POST required for notes");
};
