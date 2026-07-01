import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteDashboard, getDashboard, updateDashboard } from "../service.ts";
import { parseDeleteIdBody, parseUpdateDashboardBody, parseUuidQuery } from "../validation.ts";

export const dashboardHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getDashboard(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateDashboard(
                auth,
                parseUpdateDashboardBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.dashboard.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteDashboard(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.dashboard.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for dashboard");
};
