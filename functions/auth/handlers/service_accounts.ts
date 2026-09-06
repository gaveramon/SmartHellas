import { dispatchMethod } from "../core/index.ts";
import {
  createServiceAccount,
  deleteServiceAccount,
  listServiceAccounts,
  updateServiceAccount,
} from "../service.ts";
import {
  parseCreateServiceAccountBody,
  parseDeleteServiceAccountBody,
  parseUpdateServiceAccountBody,
} from "../validation.ts";
import { parseJsonBody, success } from "../../shared/response.ts";

export const serviceAccountsHandler = dispatchMethod(
  {
    GET: async (ctx) => {
      const accounts = await listServiceAccounts(ctx.auth);
      return success(accounts);
    },
    POST: async (ctx) => {
      const account = await createServiceAccount(
        ctx.auth,
        parseCreateServiceAccountBody(await parseJsonBody(ctx.req)),
      );
      await ctx.logger.audit("auth.service_account.created", {
        service_account_id: account.id,
      });
      return success(account, undefined, 201);
    },
    PATCH: async (ctx) => {
      const updatedAccount = await updateServiceAccount(
        ctx.auth,
        parseUpdateServiceAccountBody(await parseJsonBody(ctx.req)),
      );
      await ctx.logger.audit("auth.service_account.updated", {
        service_account_id: updatedAccount.id,
      });
      return success(updatedAccount);
    },
    DELETE: async (ctx) => {
      const deleted = await deleteServiceAccount(
        ctx.auth,
        parseDeleteServiceAccountBody(await parseJsonBody(ctx.req)).service_account_id,
      );
      await ctx.logger.audit("auth.service_account.deleted", {
        service_account_id: deleted.service_account_id,
      });
      return success(deleted);
    },
  },
  "service-accounts",
);
