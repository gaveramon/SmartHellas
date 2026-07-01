import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteList, getList, updateList } from "../service.ts";
import { parseDeleteIdBody, parseUpdateListBody, parseUuidQuery } from "../validation.ts";

export const listHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await getList(auth, parseUuidQuery(req)));
            if (req.method === "PATCH") {
              const updated = await updateList(auth, parseUpdateListBody(await parseJsonBody(req)));
              await logger.audit("crm.list.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteList(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.list.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for list");
};
