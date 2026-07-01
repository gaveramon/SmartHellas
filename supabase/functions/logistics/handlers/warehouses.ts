import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createWarehouse, listWarehouses } from "../service.ts";
import { parseCreateWarehouseBody } from "../validation.ts";

export const warehousesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await listWarehouses(auth));
            }
            if (req.method === "POST") {
              const created = await createWarehouse(
                auth,
                parseCreateWarehouseBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.warehouse.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for warehouses");
};
