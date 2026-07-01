import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { listUserPreferences, upsertUserPreference } from "../service.ts";
import { parseUpsertPreferenceBody } from "../validation.ts";

export const preferencesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listUserPreferences(auth));
            }
            if (req.method === "PUT" || req.method === "POST") {
              const pref = await upsertUserPreference(
                auth,
                parseUpsertPreferenceBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.preference.upserted", {
                preference_key: pref.preference_key,
              });
              return success(pref);
            }
            throw new ValidationError("GET, PUT, or POST required for preferences");
};
