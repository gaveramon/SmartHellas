import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteProperty, getProperty, updateProperty } from "../service.ts";
import { parseDeletePropertyBody, parseUpdatePropertyBody, parseUuidQuery } from "../validation.ts";

export const propertyHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const property = await getProperty(auth, parseUuidQuery(req));
              return success(property);
            }
            if (req.method === "PATCH") {
              const updated = await updateProperty(
                auth,
                parseUpdatePropertyBody(await parseJsonBody(req)),
              );
              await logger.audit("devices.property.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteProperty(
                auth,
                parseDeletePropertyBody(await parseJsonBody(req)).id,
              );
              await logger.audit("devices.property.deleted", { id: deleted.id });
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for property");
};
