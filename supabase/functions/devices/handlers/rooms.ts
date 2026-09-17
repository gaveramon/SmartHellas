import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createRoom, listRooms } from "../service.ts";
import { optionalUuidQuery, parseCreateRoomBody } from "../validation.ts";

export const roomsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const propertyId = optionalUuidQuery(req, "property_id");
              const rooms = await listRooms(auth, propertyId);
              return success(rooms);
            }
            if (req.method === "POST") {
              const room = await createRoom(
                auth,
                parseCreateRoomBody(await parseJsonBody(req)),
              );
              await logger.audit("devices.room.created", { id: room.id });
              return success(room, undefined, 201);
            }
            throw new ValidationError("GET or POST required for rooms");
};
