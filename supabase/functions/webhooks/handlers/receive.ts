import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { requireWebhookSignature, readWebhookBody } from "../../shared/webhook.ts";
import { success } from "../../shared/response.ts";
import { ingestWebhook } from "../service.ts";
import { parseProviderSource } from "../validation.ts";

function webhookSecretForSource(source: string): string | undefined {
  const normalized = source.toUpperCase().replace(/[^A-Z0-9]/g, "_");
  return Deno.env.get(`WEBHOOK_SECRET_${normalized}`);
}

/** Generic provider ingress: POST /webhooks/receive?source=<provider> */
export const receiveHandler = async (ctx: HandlerContext) => {
  const { req, logger } = ctx;
  if (req.method !== "POST") {
    throw new ValidationError("POST required for receive");
  }

  const source = parseProviderSource(req, "unknown");
  const rawBody = await readWebhookBody(req);
  const secret = webhookSecretForSource(source);

  if (secret) {
    const signature = req.headers.get("X-Webhook-Signature") ??
      req.headers.get("X-Hub-Signature-256") ??
      "";
    if (!signature) {
      throw new ValidationError("Webhook signature header required");
    }
    await requireWebhookSignature({
      secret,
      signatureHeader: signature,
      payload: rawBody,
    });
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    throw new ValidationError("Webhook body must be valid JSON");
  }

  const externalEventId = typeof payload.id === "string"
    ? payload.id
    : typeof payload.event_id === "string"
    ? payload.event_id
    : null;

  if (!externalEventId) {
    throw new ValidationError("Webhook payload must include id or event_id");
  }

  const eventType = typeof payload.type === "string"
    ? payload.type
    : typeof payload.event_type === "string"
    ? payload.event_type
    : "provider.event";

  const externalAccountId = typeof payload.account === "string"
    ? payload.account
    : typeof payload.account_id === "string"
    ? payload.account_id
    : undefined;

  const result = await ingestWebhook({
    source,
    external_event_id: externalEventId,
    event_type: eventType,
    payload,
    external_account_id: externalAccountId,
  });

  await logger.audit("webhooks.received", {
    source: result.source,
    external_event_id: result.external_event_id,
    event_type: eventType,
  });
  return success(result, undefined, 202);
};
