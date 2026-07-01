import type { JobHandlerContext } from "../core/index.ts";
import { success } from "../../shared/response.ts";
import { runCronTickJob } from "../service.ts";

export const cronTickHandler = async (ctx: JobHandlerContext) => {
  const { correlationId } = ctx;
  const result = await runCronTickJob(correlationId);
  return success(result);
};
