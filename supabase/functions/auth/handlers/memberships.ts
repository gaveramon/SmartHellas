import { dispatchMethod } from "../core/index.ts";
import {
  inviteMember,
  listMemberships,
  revokeMembership,
  updateMembership,
} from "../service.ts";
import {
  parseInviteMemberBody,
  parseRevokeMembershipBody,
  parseUpdateMembershipBody,
} from "../validation.ts";
import { parseJsonBody, success } from "../../shared/response.ts";

export const membershipsHandler = dispatchMethod(
  {
    GET: async (ctx) => {
      const members = await listMemberships(ctx.auth);
      return success(members);
    },
    POST: async (ctx) => {
      const invite = parseInviteMemberBody(await parseJsonBody(ctx.req));
      const member = await inviteMember(ctx.auth, invite.email, invite.role);
      await ctx.logger.audit("auth.membership.invited", {
        membership_id: member.id,
      });
      return success(member, undefined, 201);
    },
    PATCH: async (ctx) => {
      const updatedMember = await updateMembership(
        ctx.auth,
        parseUpdateMembershipBody(await parseJsonBody(ctx.req)),
      );
      await ctx.logger.audit("auth.membership.updated", {
        membership_id: updatedMember.id,
      });
      return success(updatedMember);
    },
    DELETE: async (ctx) => {
      const revoked = await revokeMembership(
        ctx.auth,
        parseRevokeMembershipBody(await parseJsonBody(ctx.req)).membership_id,
      );
      await ctx.logger.audit("auth.membership.revoked", {
        membership_id: revoked.membership_id,
      });
      return success(revoked);
    },
  },
  "memberships",
);
