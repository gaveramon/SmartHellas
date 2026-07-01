import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createFeatureEntitlement, listFeatureEntitlements } from "../service.ts";
import { parseCreateEntitlementBody, parseUuidQuery } from "../validation.ts";

export const entitlementsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listFeatureEntitlements(auth, parseUuidQuery(req, "plan_id")),
              );
            }
            if (req.method === "POST") {
              const created = await createFeatureEntitlement(
                auth,
                parseCreateEntitlementBody(await parseJsonBody(req)),
              );
              await logger.audit("commerce.entitlement.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for entitlements");
};
