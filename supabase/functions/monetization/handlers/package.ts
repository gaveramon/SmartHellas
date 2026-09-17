import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deletePackage, getPackage, updatePackage } from "../service.ts";
import { parseDeleteIdBody, parseUpdatePackageBody, parseUuidQuery } from "../validation.ts";

export const packageHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getPackage(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updatePackage(
                auth,
                parseUpdatePackageBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.package.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deletePackage(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.package.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for package");
};
