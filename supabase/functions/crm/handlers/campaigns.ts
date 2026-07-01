import type { HandlerContext } from "../core/index.ts";
import { ValidationError } from "../../shared/errors.ts";
import { parseJsonBody, success } from "../../shared/response.ts";
import { createCampaign, listCampaigns } from "../service.ts";
import { CRM_CAMPAIGN_STATUSES, optionalEnumQuery, parseCreateCampaignBody } from "../validation.ts";

export const campaignsHandler = async (ctx: HandlerContext) => {
  const { req, auth, logger } = ctx;
  if (req.method === "GET") {
              return success(
                await listCampaigns(
                  auth,
                  optionalEnumQuery(req, "status", CRM_CAMPAIGN_STATUSES),
                ),
              );
            }
            if (req.method === "POST") {
              const created = await createCampaign(auth, parseCreateCampaignBody(await parseJsonBody(req)));
              await logger.audit("crm.campaign.created", { id: created.id });
              return success(created, undefined, 201);
            }
            throw new ValidationError("GET or POST required for campaigns");
};
