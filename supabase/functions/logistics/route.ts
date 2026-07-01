import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { templatesHandler } from "./handlers/templates.ts";
import { templateHandler } from "./handlers/template.ts";
import { packagesHandler } from "./handlers/packages.ts";
import { packageHandler } from "./handlers/package.ts";
import { carriersHandler } from "./handlers/carriers.ts";
import { carrierHandler } from "./handlers/carrier.ts";
import { warehousesHandler } from "./handlers/warehouses.ts";
import { warehouseHandler } from "./handlers/warehouse.ts";
import { labelTemplatesHandler } from "./handlers/label_templates.ts";
import { labelTemplateHandler } from "./handlers/label_template.ts";
import { shippingRulesHandler } from "./handlers/shipping_rules.ts";
import { shippingRuleHandler } from "./handlers/shipping_rule.ts";
import { fulfilmentOrdersHandler } from "./handlers/fulfilment_orders.ts";
import { fulfilmentOrderHandler } from "./handlers/fulfilment_order.ts";
import { dispatchHandler } from "./handlers/dispatch.ts";

export const resolveRoute = createRouteResolver("logistics");

export const routeHandlers: RouteHandlerMap = {
  "templates": templatesHandler,
  "template": templateHandler,
  "packages": packagesHandler,
  "package": packageHandler,
  "carriers": carriersHandler,
  "carrier": carrierHandler,
  "warehouses": warehousesHandler,
  "warehouse": warehouseHandler,
  "label-templates": labelTemplatesHandler,
  "label-template": labelTemplateHandler,
  "shipping-rules": shippingRulesHandler,
  "shipping-rule": shippingRuleHandler,
  "fulfilment-orders": fulfilmentOrdersHandler,
  "fulfilment-order": fulfilmentOrderHandler,
  "dispatch": dispatchHandler,
};
