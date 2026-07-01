import type { JobHandlerContext } from "../core/index.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { ingestShipmentTracking } from "../service.ts";
import { parseShipmentTracking } from "../validation.ts";

export const shipmentTrackingHandler = async (ctx: JobHandlerContext) => {
  const { req, correlationId } = ctx;
  const input = parseShipmentTracking(await parseJsonBody(req));
  const result = await ingestShipmentTracking(input, correlationId);
  return success(result);
};
