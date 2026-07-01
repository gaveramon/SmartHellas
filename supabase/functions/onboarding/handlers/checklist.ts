import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { listChecklistItems, upsertChecklistItem } from "../service.ts";
import { parseUpsertChecklistBody, parseUuidQuery } from "../validation.ts";

export const checklistHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listChecklistItems(auth, parseUuidQuery(req, "session_id")),
              );
            }
            if (req.method === "PUT" || req.method === "POST") {
              const item = await upsertChecklistItem(
                auth,
                parseUpsertChecklistBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.checklist.upserted", { id: item.id });
              return success(item);
            }
            throw new ValidationError("GET, PUT, or POST required for checklist");
};
