import type { JobHandlerContext } from "../core/index.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { runNotificationsDeliveryWorker } from "../service.ts";
import { parseBatchOptions } from "../validation.ts";

export const notificationsDeliveryHandler = async (ctx: JobHandlerContext) => {
  const { req, correlationId } = ctx;
  const options = parseBatchOptions(
    req.headers.get("Content-Length") === "0"
      ? {}
      : await parseJsonBody(req, { allowEmpty: true }),
  );
  const result = await runNotificationsDeliveryWorker(options, correlationId);
  return success(result);
};
