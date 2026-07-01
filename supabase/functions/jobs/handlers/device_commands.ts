import type { JobHandlerContext } from "../core/index.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { runDeviceCommandWorker } from "../service.ts";
import { parseBatchOptions } from "../validation.ts";

export const deviceCommandsHandler = async (ctx: JobHandlerContext) => {
  const { req, correlationId } = ctx;
  const options = parseBatchOptions(
    req.headers.get("Content-Length") === "0"
      ? {}
      : await parseJsonBody(req, { allowEmpty: true }),
  );
  const result = await runDeviceCommandWorker(options, correlationId);
  return success(result);
};
