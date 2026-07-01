import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteCampaign, getCampaign, updateCampaign } from "../service.ts";
import { parseDeleteIdBody, parseUpdateCampaignBody, parseUuidQuery } from "../validation.ts";

export const campaignHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") return success(await getCampaign(auth, parseUuidQuery(req)));
            if (req.method === "PATCH") {
              const updated = await updateCampaign(auth, parseUpdateCampaignBody(await parseJsonBody(req)));
              await logger.audit("crm.campaign.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteCampaign(auth, parseDeleteIdBody(await parseJsonBody(req)));
              await logger.audit("crm.campaign.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for campaign");
};
