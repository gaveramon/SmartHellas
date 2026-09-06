import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deletePreconfigDeviceMap, updatePreconfigDeviceMap } from "../service.ts";
import { parseDeleteIdBody, parseUpdateDeviceMapBody } from "../validation.ts";

export const deviceMapEntryHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updatePreconfigDeviceMap(
                auth,
                parseUpdateDeviceMapBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.device_map.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deletePreconfigDeviceMap(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.device_map.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for device-map-entry");
};
