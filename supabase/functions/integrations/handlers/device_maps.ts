import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createDeviceMap, listDeviceMaps } from "../service.ts";
import { optionalCodeQuery, optionalUuidQuery, parseCreateDeviceMapBody } from "../validation.ts";

export const deviceMapsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
            return success(
              await listDeviceMaps(
                auth,
                optionalUuidQuery(req, "device_id"),
                optionalCodeQuery(req, "provider_code"),
              ),
            );
          }
          if (req.method === "POST") {
            const createdMap = await createDeviceMap(
              auth,
              parseCreateDeviceMapBody(await parseJsonBody(req)),
            );
            await logger.audit("integrations.device_map.created", { id: createdMap.id });
            return success(createdMap, undefined, 201);
          }
          throw new ValidationError("GET or POST required for device-maps");
};
