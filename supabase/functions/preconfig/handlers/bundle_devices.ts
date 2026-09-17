import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createBundleDevice, listBundleDevices } from "../service.ts";
import { parseCreateBundleDeviceBody, parseUuidQuery } from "../validation.ts";

export const bundleDevicesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listBundleDevices(auth, parseUuidQuery(req, "bundle_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createBundleDevice(
                auth,
                parseCreateBundleDeviceBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.bundle_device.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for bundle-devices");
};
