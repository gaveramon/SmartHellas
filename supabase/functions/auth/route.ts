import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { contextHandler } from "./handlers/context.ts";
import { membershipsHandler } from "./handlers/memberships.ts";
import { serviceAccountsHandler } from "./handlers/service_accounts.ts";
import { subscriptionHandler } from "./handlers/subscription.ts";
import { switchTenantHandler } from "./handlers/switch_tenant.ts";
import { tenantHandler } from "./handlers/tenant.ts";
import { tenantCreateHandler } from "./handlers/tenant_create.ts";
import { tenantsHandler } from "./handlers/tenants.ts";

export const resolveRoute = createRouteResolver("auth");

export const routeHandlers: RouteHandlerMap = {
  context: contextHandler,
  tenants: tenantsHandler,
  "switch-tenant": switchTenantHandler,
  tenant: tenantHandler,
  "tenant-create": tenantCreateHandler,
  memberships: membershipsHandler,
  subscription: subscriptionHandler,
  "service-accounts": serviceAccountsHandler,
};
