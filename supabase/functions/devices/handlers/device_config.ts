import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { getDeviceConfig, upsertDeviceConfig } from "../service.ts";
import { parseDeviceConfigQuery, parseUpsertDeviceConfigBody } from "../validation.ts";

export const deviceConfigHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const config = await getDeviceConfig(
                auth,
                parseDeviceConfigQuery(req),
              );
              return success(config);
            }
            if (req.method === "PUT" || req.method === "PATCH") {
              const config = await upsertDeviceConfig(
                auth,
                parseUpsertDeviceConfigBody(await parseJsonBody(req)),
              );
              await logger.audit("devices.config.upserted", {
                device_id: config.device_id,
              });
              return success(config);
            }
            throw new ValidationError("GET, PUT, or PATCH required for device-config");
};
