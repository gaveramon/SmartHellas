import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteBundleDevice, updateBundleDevice } from "../service.ts";
import { parseDeleteIdBody, parseUpdateBundleDeviceBody } from "../validation.ts";

export const bundleDeviceHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateBundleDevice(
                auth,
                parseUpdateBundleDeviceBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.bundle_device.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteBundleDevice(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.bundle_device.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for bundle-device");
};
