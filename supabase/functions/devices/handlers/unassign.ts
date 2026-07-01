import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { unassignDevice } from "../service.ts";
import { parseUnassignDeviceBody } from "../validation.ts";

export const unassignHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
              throw new ValidationError("POST required for unassign");
            }
            const unassigned = await unassignDevice(
              auth,
              parseUnassignDeviceBody(await parseJsonBody(req)),
            );
            await logger.audit("devices.device.unassigned", {
              device_id: unassigned.device_id,
            });
            return success(unassigned);
};
