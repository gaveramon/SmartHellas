import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { startOAuth } from "../service.ts";
import { parseOAuthStartBody } from "../validation.ts";

export const oauthStartHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
            throw new ValidationError("POST required for oauth-start");
          }
          const oauth = await startOAuth(auth, parseOAuthStartBody(await parseJsonBody(req)));
          await logger.audit("integrations.oauth_started", {
            provider_code: oauth.provider_code,
          });
          return success(oauth);
};
