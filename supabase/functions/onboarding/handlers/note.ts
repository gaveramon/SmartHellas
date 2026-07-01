import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteNote } from "../service.ts";
import { parseDeleteIdBody } from "../validation.ts";

export const noteHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "DELETE") {
              const deleted = await deleteNote(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("onboarding.note.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("DELETE required for note");
};
