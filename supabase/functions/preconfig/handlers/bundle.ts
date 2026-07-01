import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteDeviceBundle, getDeviceBundleByCode, getDeviceBundleById, updateDeviceBundle } from "../service.ts";
import { optionalUuidQuery, parseBundleVersionQuery, parseCodeQuery, parseDeleteIdBody, parseUpdateBundleBody } from "../validation.ts";

export const bundleHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const id = optionalUuidQuery(req, "id");
              if (id) {
                return success(await getDeviceBundleById(auth, id));
              }
              return success(
                await getDeviceBundleByCode(
                  auth,
                  parseCodeQuery(req),
                  parseBundleVersionQuery(req),
                ),
              );
            }
            if (req.method === "PATCH") {
              const updated = await updateDeviceBundle(
                auth,
                parseUpdateBundleBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.bundle.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteDeviceBundle(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.bundle.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for bundle");
};
