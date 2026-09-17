import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { success } from "../../shared/response.ts";
import { listEnergyProfiles } from "../service.ts";
import { optionalUuidQuery } from "../validation.ts";

export const energyProfilesHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listEnergyProfiles(auth, optionalUuidQuery(req, "property_id")),
              );
            }
            throw new ValidationError("GET required for energy-profiles");
};
