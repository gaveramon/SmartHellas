import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { enqueueNotification } from "../service.ts";

export const enqueueHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") throw new ValidationError("POST required for enqueue");
  const body = await parseJsonBody(req) as Record<string, unknown>;
  const result = await enqueueNotification(auth, body as never);
  await logger.audit("notifications.enqueued", { id: (result as { id?: string }).id });
  return success(result, undefined, 201);
};
