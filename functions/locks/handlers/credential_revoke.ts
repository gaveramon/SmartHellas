import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { revokeCredential } from "../service.ts";
import { parseRevokeCredentialBody } from "../validation.ts";

export const credentialRevokeHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
              throw new ValidationError("POST required for credential-revoke");
            }
            const revoked = await revokeCredential(
              auth,
              parseRevokeCredentialBody(await parseJsonBody(req)),
            );
            await logger.audit("locks.credential.revoke", {
              credential_id: revoked.credential.id,
            });
            return success(revoked);
};
