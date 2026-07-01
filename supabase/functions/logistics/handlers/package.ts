import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deletePackageDefinition, updatePackageDefinition } from "../service.ts";
import { parseDeleteIdBody, parseUpdatePackageDefinitionBody } from "../validation.ts";

export const packageHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "PATCH") {
              const updated = await updatePackageDefinition(
                auth,
                parseUpdatePackageDefinitionBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.package.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deletePackageDefinition(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.package.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("PATCH or DELETE required for package");
};
