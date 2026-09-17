import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listTemplates } from "../service.ts";

export const templatesHandler = async (ctx: HandlerContext) => {
  const { req, auth } = ctx;
  if (req.method !== "GET") throw new ValidationError("GET required for templates");
  return success(await listTemplates(auth));
};
