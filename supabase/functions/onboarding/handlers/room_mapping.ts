import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteRoomMapping, updateRoomMapping } from "../service.ts";
import { parseDeleteIdBody, parseUpdateRoomMappingBody } from "../validation.ts";

export const roomMappingHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updateRoomMapping(
                auth,
                parseUpdateRoomMappingBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.room_mapping.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteRoomMapping(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("onboarding.room_mapping.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for room-mapping");
};
