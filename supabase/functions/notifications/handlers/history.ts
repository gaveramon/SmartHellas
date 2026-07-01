import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listHistory } from "../service.ts";

export const historyHandler = async (ctx: HandlerContext) => {
  const { req, auth } = ctx;
  if (req.method !== "GET") throw new ValidationError("GET required for history");
  const channel = new URL(req.url).searchParams.get("channel") ?? undefined;
  return success(await listHistory(auth, channel));
};
