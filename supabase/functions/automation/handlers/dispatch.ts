import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { dispatchEvent } from "../service.ts";
import { parseDispatchEventBody } from "../validation.ts";

export const dispatchHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "POST") {
    throw new ValidationError("POST required for dispatch");
  }
  const result = await dispatchEvent(auth, parseDispatchEventBody(await parseJsonBody(req)));
  await logger.audit("automation.dispatch", result);
  return success(result);
};
