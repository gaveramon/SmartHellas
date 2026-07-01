import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createAccessPolicy, listAccessPolicies } from "../service.ts";
import { optionalUuidQuery, parseCreateAccessPolicyBody } from "../validation.ts";

export const accessPoliciesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              const propertyId = optionalUuidQuery(req, "property_id");
              return success(await listAccessPolicies(auth, propertyId));
            }
            if (req.method === "POST") {
              const policy = await createAccessPolicy(
                auth,
                parseCreateAccessPolicyBody(await parseJsonBody(req)),
              );
              await logger.audit("booking.access_policy.created", { id: policy.id });
              return success(policy, undefined, 201);
            }
            throw new ValidationError("GET or POST required for access-policies");
};
