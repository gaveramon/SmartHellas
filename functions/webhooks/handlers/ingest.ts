import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { requireJobAuth } from "../../shared/job-auth.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { ingestWebhook } from "../service.ts";
import { parseIngestWebhookBody } from "../validation.ts";

/** Trusted ingestion for internal workers or configured job secret. */
export const ingestHandler = async (ctx: HandlerContext) => {
  const { req, logger } = ctx;
  if (req.method !== "POST") {
    throw new ValidationError("POST required for ingest");
  }

  requireJobAuth(req);

  const input = parseIngestWebhookBody(await parseJsonBody(req));
  const result = await ingestWebhook(input);
  await logger.audit("webhooks.ingested", {
    source: result.source,
    external_event_id: result.external_event_id,
  });
  return success(result, undefined, 202);
};
