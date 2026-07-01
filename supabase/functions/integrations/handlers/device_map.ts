import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteDeviceMap, updateDeviceMap } from "../service.ts";
import { parseDeleteIdBody, parseUpdateDeviceMapBody } from "../validation.ts";

export const deviceMapHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
            const updatedMap = await updateDeviceMap(
              auth,
              parseUpdateDeviceMapBody(await parseJsonBody(req)),
            );
            await logger.audit("integrations.device_map.updated", { id: updatedMap.id });
            return success(updatedMap);
          }
          if (req.method === "DELETE") {
            const deletedMap = await deleteDeviceMap(
              auth,
              parseDeleteIdBody(await parseJsonBody(req)),
            );
            await logger.audit("integrations.device_map.deleted", deletedMap);
            return success(deletedMap);
          }
          throw new ValidationError("PATCH or DELETE required for device-map");
};
