import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createDevice, listDevices } from "../service.ts";
import { optionalUuidQuery, parseCreateDeviceBody } from "../validation.ts";

export const devicesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const propertyId = optionalUuidQuery(req, "property_id");
              const roomId = optionalUuidQuery(req, "room_id");
              const devices = await listDevices(auth, propertyId, roomId);
              return success(devices);
            }
            if (req.method === "POST") {
              const device = await createDevice(
                auth,
                parseCreateDeviceBody(await parseJsonBody(req)),
              );
              await logger.audit("devices.device.created", { id: device.id });
              return success(device, undefined, 201);
            }
            throw new ValidationError("GET or POST required for devices");
};
