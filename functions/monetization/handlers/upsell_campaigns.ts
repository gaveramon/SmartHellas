import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createUpsellCampaign, listUpsellCampaigns } from "../service.ts";
import { optionalEnumQuery, parseCreateUpsellCampaignBody, parseActiveOnlyQuery, UPSELL_PACKAGE_TRIGGERS } from "../validation.ts";

export const upsellCampaignsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listUpsellCampaigns(
                  auth,
                  optionalEnumQuery(req, "trigger_event", UPSELL_PACKAGE_TRIGGERS),
                  parseActiveOnlyQuery(req),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createUpsellCampaign(
                auth,
                parseCreateUpsellCampaignBody(await parseJsonBody(req)),
              );
              await logger.audit("monetization.upsell_campaign.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for upsell-campaigns");
};
