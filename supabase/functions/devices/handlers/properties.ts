import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createProperty, listProperties } from "../service.ts";
import { parseCreatePropertyBody } from "../validation.ts";

export const propertiesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const items = await listProperties(auth);
              return success(items);
            }
            if (req.method === "POST") {
              const created = await createProperty(
                auth,
                parseCreatePropertyBody(await parseJsonBody(req)),
              );
              await logger.audit("devices.property.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for properties");
};
