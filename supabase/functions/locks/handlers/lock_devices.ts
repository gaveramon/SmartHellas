import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createLockDevice, listLockDevices } from "../service.ts";
import { optionalUuidQuery, parseCreateLockDeviceBody } from "../validation.ts";

export const lockDevicesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const propertyId = optionalUuidQuery(req, "property_id");
              return success(await listLockDevices(auth, propertyId));
            }
            if (req.method === "POST") {
              const lock = await createLockDevice(
                auth,
                parseCreateLockDeviceBody(await parseJsonBody(req)),
              );
              await logger.audit("locks.device.linked", { id: lock.id });
              return success(lock, undefined, 201);
            }
            throw new ValidationError("GET or POST required for lock-devices");
};
