import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createListMember, listListMembers } from "../service.ts";
import { parseCreateListMemberBody, parseUuidQuery } from "../validation.ts";

export const listMembersHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listListMembers(auth, parseUuidQuery(req, "list_id")));
            }
            if (req.method === "POST") {
              const created = await createListMember(
                auth,
                parseCreateListMemberBody(await parseJsonBody(req)),
              );
              await logger.audit("crm.list_member.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for list-members");
};
