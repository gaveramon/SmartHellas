import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listQueue } from "../service.ts";

export const queueHandler = async (ctx: HandlerContext) => {
  const { req, auth } = ctx;
  if (req.method !== "GET") throw new ValidationError("GET required for queue");
  const status = new URL(req.url).searchParams.get("status") ?? undefined;
  return success(await listQueue(auth, status));
};
