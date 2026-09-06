import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { issueCredential } from "../service.ts";
import { parseIssueCredentialBody } from "../validation.ts";

export const credentialIssueHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
              throw new ValidationError("POST required for credential-issue");
            }
            const issued = await issueCredential(
              auth,
              parseIssueCredentialBody(await parseJsonBody(req)),
            );
            await logger.audit("locks.credential.issue", {
              credential_id: issued.credential.id,
              command_id: issued.command_id,
            });
            return success(issued, undefined, 201);
};
