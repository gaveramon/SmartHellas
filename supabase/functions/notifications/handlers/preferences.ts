import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { listPreferences, upsertPreference } from "../service.ts";

export const preferencesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
    const userId = new URL(req.url).searchParams.get("user_id") ?? undefined;
    return success(await listPreferences(auth, userId));
  }
  if (req.method === "PUT" || req.method === "POST") {
    const pref = await upsertPreference(auth, await parseJsonBody(req) as never);
    await logger.audit("notifications.preference.upserted", { id: pref.id });
    return success(pref);
  }
  throw new ValidationError("GET or PUT/POST required for preferences");
};
