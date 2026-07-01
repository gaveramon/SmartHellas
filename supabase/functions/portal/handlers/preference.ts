import type { HandlerContext } from "../core/index.ts";
import { ValidationError, NotFoundError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteUserPreference, getUserPreference, updateUserPreference } from "../service.ts";
import { parseDeletePreferenceBody, parsePreferenceKeyQuery, parseUpdatePreferenceBody } from "../validation.ts";

export const preferenceHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const key = parsePreferenceKeyQuery(req);
              const pref = await getUserPreference(auth, key);
              if (!pref) throw new NotFoundError("Preference not found");
              return success(pref);
            }
            if (req.method === "PATCH") {
              const updated = await updateUserPreference(
                auth,
                parseUpdatePreferenceBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.preference.updated", {
                preference_key: updated.preference_key,
              });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteUserPreference(
                auth,
                parseDeletePreferenceBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.preference.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for preference");
};
