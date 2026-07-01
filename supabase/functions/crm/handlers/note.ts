import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteNote, updateNote } from "../service.ts";
import { parseDeleteIdBody, parseUpdateNoteBody } from "../validation.ts";

export const noteHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateNote(auth, parseUpdateNoteBody(await parseJsonBody(req)));
              await logger.audit("crm.note.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteNote(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.note.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for note");
};
