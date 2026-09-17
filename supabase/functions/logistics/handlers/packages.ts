import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createPackageDefinition, listPackageDefinitions } from "../service.ts";
import { parseCreatePackageDefinitionBody, parseUuidQuery } from "../validation.ts";

export const packagesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listPackageDefinitions(auth, parseUuidQuery(req, "template_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createPackageDefinition(
                auth,
                parseCreatePackageDefinitionBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.package.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for packages");
};
