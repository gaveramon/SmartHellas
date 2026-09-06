import type { JobHandlerContext } from "../core/index.ts";
import { success } from "../../shared/response.ts";
import { runDailyMaintenanceJob } from "../service.ts";

export const dailyMaintenanceHandler = async (ctx: JobHandlerContext) => {
  const { correlationId } = ctx;
  const result = await runDailyMaintenanceJob(correlationId);
  return success(result);
};
