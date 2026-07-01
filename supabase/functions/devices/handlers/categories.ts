import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listDeviceCategories } from "../service.ts";

export const categoriesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method !== "GET") {
              throw new ValidationError("GET required for categories");
            }
            const categories = await listDeviceCategories(auth);
            return success(categories);
};
