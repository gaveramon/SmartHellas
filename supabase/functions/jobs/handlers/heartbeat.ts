import type { JobHandlerContext } from "../core/index.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { recordHeartbeat } from "../service.ts";
import { parseHeartbeat } from "../validation.ts";

export const heartbeatHandler = async (ctx: JobHandlerContext) => {
  const { req, correlationId } = ctx;
  const input = parseHeartbeat(await parseJsonBody(req));
  await recordHeartbeat(input, correlationId);
  return success({ recorded: true, correlation_id: correlationId });
};
