import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createDashboard, listDashboards } from "../service.ts";
import { parseCreateDashboardBody } from "../validation.ts";

export const dashboardsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listDashboards(auth));
            }
            if (req.method === "POST") {
              const created = await createDashboard(
                auth,
                parseCreateDashboardBody(await parseJsonBody(req)),
              );
              await logger.audit("portal.dashboard.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for dashboards");
};
