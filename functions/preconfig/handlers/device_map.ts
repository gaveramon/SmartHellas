import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createPreconfigDeviceMap, listPreconfigDeviceMap } from "../service.ts";
import { parseCreateDeviceMapBody, parseUuidQuery } from "../validation.ts";

export const deviceMapHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listPreconfigDeviceMap(auth, parseUuidQuery(req, "template_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createPreconfigDeviceMap(
                auth,
                parseCreateDeviceMapBody(await parseJsonBody(req)),
              );
              await logger.audit("preconfig.device_map.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for device-map");
};
