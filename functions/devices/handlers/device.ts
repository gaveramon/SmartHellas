import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteDevice, getDevice, updateDevice } from "../service.ts";
import { parseDeleteDeviceBody, parseUpdateDeviceBody, parseUuidQuery } from "../validation.ts";

export const deviceHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const device = await getDevice(auth, parseUuidQuery(req));
              return success(device);
            }
            if (req.method === "PATCH") {
              const updated = await updateDevice(
                auth,
                parseUpdateDeviceBody(await parseJsonBody(req)),
              );
              await logger.audit("devices.device.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteDevice(
                auth,
                parseDeleteDeviceBody(await parseJsonBody(req)).id,
              );
              await logger.audit("devices.device.deleted", { id: deleted.id });
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for device");
};
