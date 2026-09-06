import type { HandlerContext } from "../core/index.ts";
import { ValidationError, NotFoundError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { getTenantIntegration, updateIntegration } from "../service.ts";
import { parseCodeQuery, parseUpdateIntegrationBody } from "../validation.ts";

export const connectionHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
            const code = parseCodeQuery(req);
            const row = await getTenantIntegration(auth, code);
            if (!row) {
              throw new NotFoundError("Integration not connected");
            }
            return success(row);
          }
          if (req.method === "PATCH") {
            const updated = await updateIntegration(
              auth,
              parseUpdateIntegrationBody(await parseJsonBody(req)),
            );
            await logger.audit("integrations.connection.updated", {
              provider_code: updated.provider_code,
            });
            return success(updated);
          }
          throw new ValidationError("GET or PATCH required for connection");
};
