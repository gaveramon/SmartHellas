import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { disconnectIntegration } from "../service.ts";
import { parseDisconnectBody } from "../validation.ts";

export const disconnectHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
            throw new ValidationError("POST required for disconnect");
          }
          const disconnected = await disconnectIntegration(
            auth,
            parseDisconnectBody(await parseJsonBody(req)),
          );
          await logger.audit("integrations.disconnected", disconnected);
          return success(disconnected);
};
