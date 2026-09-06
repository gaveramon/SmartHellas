import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteRoom, getRoom, updateRoom } from "../service.ts";
import { parseDeleteRoomBody, parseUpdateRoomBody, parseUuidQuery } from "../validation.ts";

export const roomHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const room = await getRoom(auth, parseUuidQuery(req));
              return success(room);
            }
            if (req.method === "PATCH") {
              const updated = await updateRoom(
                auth,
                parseUpdateRoomBody(await parseJsonBody(req)),
              );
              await logger.audit("devices.room.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteRoom(
                auth,
                parseDeleteRoomBody(await parseJsonBody(req)).id,
              );
              await logger.audit("devices.room.deleted", { id: deleted.id });
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for room");
};
