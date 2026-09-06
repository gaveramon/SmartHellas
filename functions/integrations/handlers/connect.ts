import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { connectIntegration } from "../service.ts";
import { parseConnectBody } from "../validation.ts";

export const connectHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
            throw new ValidationError("POST required for connect");
          }
          const connected = await connectIntegration(
            auth,
            parseConnectBody(await parseJsonBody(req)),
          );
          await logger.audit("integrations.connected", {
            provider_code: connected.provider_code,
          });
          return success(connected, undefined, 201);
};
