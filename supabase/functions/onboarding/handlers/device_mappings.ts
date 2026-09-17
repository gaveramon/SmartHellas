import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createDeviceMapping, listDeviceMappings } from "../service.ts";
import { parseCreateDeviceMappingBody, parseUuidQuery } from "../validation.ts";

export const deviceMappingsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listDeviceMappings(auth, parseUuidQuery(req, "session_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createDeviceMapping(
                auth,
                parseCreateDeviceMappingBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.device_mapping.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for device-mappings");
};
