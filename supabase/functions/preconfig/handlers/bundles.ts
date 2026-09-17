import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createDeviceBundle, listDeviceBundles } from "../service.ts";
import { optionalEnumQuery, parseActiveOnlyQuery, parseCreateBundleBody, PROPERTY_TYPES } from "../validation.ts";

export const bundlesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listDeviceBundles(
                  auth,
                  optionalEnumQuery(req, "property_type", PROPERTY_TYPES),
                  req.url.includes("active_only=") ? parseActiveOnlyQuery(req) : true,
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createDeviceBundle(
                auth,
                parseCreateBundleBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.bundle.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for bundles");
};
