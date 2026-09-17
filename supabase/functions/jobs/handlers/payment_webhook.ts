import type { JobHandlerContext } from "../core/index.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { runPaymentWebhookWorker } from "../service.ts";
import { parsePaymentWebhookOptions } from "../validation.ts";

export const paymentWebhookHandler = async (ctx: JobHandlerContext) => {
  const { req, correlationId } = ctx;
  const options = parsePaymentWebhookOptions(
    req.headers.get("Content-Length") === "0"
      ? {}
      : await parseJsonBody(req, { allowEmpty: true }),
  );
  const result = await runPaymentWebhookWorker(options, correlationId);
  return success(result);
};
