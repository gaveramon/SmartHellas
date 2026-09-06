import { createRouteResolver } from "../shared/core/index.ts";
import type { RouteHandlerMap } from "../shared/core/index.ts";
import { lockDevicesHandler } from "./handlers/lock_devices.ts";
import { lockDeviceHandler } from "./handlers/lock_device.ts";
import { credentialsHandler } from "./handlers/credentials.ts";
import { credentialHandler } from "./handlers/credential.ts";
import { credentialIssueHandler } from "./handlers/credential_issue.ts";
import { credentialRevokeHandler } from "./handlers/credential_revoke.ts";

export const resolveRoute = createRouteResolver("locks");

export const routeHandlers: RouteHandlerMap = {
  "lock-devices": lockDevicesHandler,
  "lock-device": lockDeviceHandler,
  "credentials": credentialsHandler,
  "credential": credentialHandler,
  "credential-issue": credentialIssueHandler,
  "credential-revoke": credentialRevokeHandler,
};
