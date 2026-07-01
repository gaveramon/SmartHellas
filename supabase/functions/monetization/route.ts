import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { proposalsHandler } from "./handlers/proposals.ts";
import { proposalHandler } from "./handlers/proposal.ts";
import { proposalItemsHandler } from "./handlers/proposal_items.ts";
import { proposalItemHandler } from "./handlers/proposal_item.ts";
import { packagesHandler } from "./handlers/packages.ts";
import { packageHandler } from "./handlers/package.ts";
import { upsellCampaignsHandler } from "./handlers/upsell_campaigns.ts";
import { upsellCampaignHandler } from "./handlers/upsell_campaign.ts";
import { activationStateHandler } from "./handlers/activation_state.ts";
import { conversionEventsHandler } from "./handlers/conversion_events.ts";
import { conversionScoresHandler } from "./handlers/conversion_scores.ts";

export const resolveRoute = createRouteResolver("monetization");

export const routeHandlers: RouteHandlerMap = {
  "proposals": proposalsHandler,
  "proposal": proposalHandler,
  "proposal-items": proposalItemsHandler,
  "proposal-item": proposalItemHandler,
  "packages": packagesHandler,
  "package": packageHandler,
  "upsell-campaigns": upsellCampaignsHandler,
  "upsell-campaign": upsellCampaignHandler,
  "activation-state": activationStateHandler,
  "conversion-events": conversionEventsHandler,
  "conversion-scores": conversionScoresHandler,
};
