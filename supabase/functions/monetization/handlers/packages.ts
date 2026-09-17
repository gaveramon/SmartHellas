import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createPackage, listPackages } from "../service.ts";
import { parseCreatePackageBody, parseActiveOnlyQuery } from "../validation.ts";

export const packagesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listPackages(auth, parseActiveOnlyQuery(req)));
            }
            if (req.method === "POST") {
              const created = await createPackage(
                auth,
                parseCreatePackageBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.package.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for packages");
};
