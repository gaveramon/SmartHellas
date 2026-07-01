import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createCarrier, listCarriers } from "../service.ts";
import { parseCreateCarrierBody } from "../validation.ts";

export const carriersHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listCarriers(auth));
            }
            if (req.method === "POST") {
              const created = await createCarrier(auth, parseCreateCarrierBody(await parseJsonBody(req)));
              await logger.audit("logistics.carrier.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for carriers");
};
