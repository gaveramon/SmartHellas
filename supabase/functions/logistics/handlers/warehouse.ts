import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteWarehouse, getWarehouse, updateWarehouse } from "../service.ts";
import { parseDeleteIdBody, parseUpdateWarehouseBody, parseUuidQuery } from "../validation.ts";

export const warehouseHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getWarehouse(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateWarehouse(
                auth,
                parseUpdateWarehouseBody(await parseJsonBody(req)),
              );
              await logger.audit("logistics.warehouse.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteWarehouse(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("logistics.warehouse.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for warehouse");
};
