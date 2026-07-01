import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteDeviceMapping, updateDeviceMapping } from "../service.ts";
import { parseDeleteIdBody, parseUpdateDeviceMappingBody } from "../validation.ts";

export const deviceMappingHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateDeviceMapping(
                auth,
                parseUpdateDeviceMappingBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.device_mapping.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteDeviceMapping(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.device_mapping.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for device-mapping");
};
