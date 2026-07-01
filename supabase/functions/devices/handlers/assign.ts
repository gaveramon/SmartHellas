import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { assignDevice } from "../service.ts";
import { parseAssignDeviceBody } from "../validation.ts";

export const assignHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
              throw new ValidationError("POST required for assign");
            }
            const assigned = await assignDevice(
              auth,
              parseAssignDeviceBody(await parseJsonBody(req)),
            );
            await logger.audit("devices.device.assigned", {
              device_id: assigned.device_id,
            });
            return success(assigned);
};
