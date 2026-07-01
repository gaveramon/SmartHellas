import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { syncIntegration } from "../service.ts";
import { parseSyncBody } from "../validation.ts";

export const syncHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
            throw new ValidationError("POST required for sync");
          }
          const synced = await syncIntegration(auth, parseSyncBody(await parseJsonBody(req)));
          await logger.audit(
            "integrations.sync_requested",
            { ...(synced as unknown as Record<string, unknown>) },
          );
          return success(synced, undefined, 202);
};
