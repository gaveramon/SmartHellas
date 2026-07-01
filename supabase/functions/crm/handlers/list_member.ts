import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteListMember } from "../service.ts";
import { parseDeleteIdBody } from "../validation.ts";

export const listMemberHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "DELETE") {
              const deleted = await deleteListMember(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.list_member.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("DELETE required for list-member");
};
