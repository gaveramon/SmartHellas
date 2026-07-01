import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteLockDevice, getLockDevice, updateLockDevice } from "../service.ts";
import { parseDeleteIdBody, parseUpdateLockDeviceBody, parseUuidQuery } from "../validation.ts";

export const lockDeviceHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getLockDevice(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              return success(
                await updateLockDevice(
                  auth,
                  parseUpdateLockDeviceBody(await parseJsonBody(req)),
                ),
              );
            }
            if (req.method === "DELETE") {
              return success(
                await deleteLockDevice(auth, parseDeleteIdBody(await parseJsonBody(req))),
              );
            }
            throw new ValidationError("GET, PATCH, or DELETE required for lock-device");
};
