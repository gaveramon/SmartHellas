import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success, failure } from "../../shared/response.ts";
import { completeOAuthCallback } from "../service.ts";
import { parseOAuthCallbackQuery } from "../validation.ts";

export const oauthCallbackHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
          throw new ValidationError("GET required for oauth-callback");
        }
  
        const query = parseOAuthCallbackQuery(req);
        if (query.error) {
          return failure(
            new ValidationError(`OAuth denied: ${query.error}`),
          );
        }
  
        const result = await completeOAuthCallback(query.code, query.state);
        await logger.audit("integrations.oauth_completed", {
          provider_code: result.provider_code,
        });
        return success(result);
};
