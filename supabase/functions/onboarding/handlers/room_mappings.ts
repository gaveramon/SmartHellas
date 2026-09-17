import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createRoomMapping, listRoomMappings } from "../service.ts";
import { parseCreateRoomMappingBody, parseUuidQuery } from "../validation.ts";

export const roomMappingsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listRoomMappings(auth, parseUuidQuery(req, "session_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createRoomMapping(
                auth,
                parseCreateRoomMappingBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.room_mapping.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for room-mappings");
};
