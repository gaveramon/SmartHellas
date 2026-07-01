import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { deleteUpsellCampaign, getUpsellCampaign, updateUpsellCampaign } from "../service.ts";
import { parseDeleteIdBody, parseUpdateUpsellCampaignBody, parseUuidQuery } from "../validation.ts";

export const upsellCampaignHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(await getUpsellCampaign(auth, parseUuidQuery(req)));
            }
            if (req.method === "PATCH") {
              const updated = await updateUpsellCampaign(
                auth,
                parseUpdateUpsellCampaignBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.upsell_campaign.updated", { id: updated.id });
              return success(updated);
            }
            if (req.method === "DELETE") {
              const deleted = await deleteUpsellCampaign(
                auth,
                parseDeleteIdBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.upsell_campaign.deleted", deleted);
              return success(deleted);
            }
            throw new ValidationError("GET, PATCH, or DELETE required for upsell-campaign");
};
