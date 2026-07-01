import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listPayments } from "../service.ts";

export const paymentsHandler = async (ctx: HandlerContext) => {
  const { req, auth } = ctx;
  if (req.method !== "GET") throw new ValidationError("GET required for payments");
  const url = new URL(req.url);
  return success(
    await listPayments(auth, {
      status: url.searchParams.get("status") ?? undefined,
      target_type: url.searchParams.get("target_type") ?? undefined,
      target_id: url.searchParams.get("target_id") ?? undefined,
    }),
  );
};
