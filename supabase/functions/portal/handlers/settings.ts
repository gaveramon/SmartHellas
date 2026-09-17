import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { getPortalSettings, upsertPortalSettings } from "../service.ts";
import { parseUpsertSettingsBody } from "../validation.ts";

export const settingsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getPortalSettings(auth));
            }
            if (req.method === "PUT" || req.method === "PATCH") {
              const settings = await upsertPortalSettings(
                auth,
                parseUpsertSettingsBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.settings.upserted", { id: settings.id });
              return success(settings);
            }
            throw new ValidationError("GET, PUT, or PATCH required for settings");
};
