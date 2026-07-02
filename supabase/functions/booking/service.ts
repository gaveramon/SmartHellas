import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  AccessPolicyRow,
  AccessRuleRow,
  BookingAccessRow,
  BookingRow,
  CreateAccessPolicyRequest,
  CreateAccessRuleRequest,
  CreateBookingAccessRequest,
  CreateBookingRequest,
  PropertyAccessScheduleRow,
  UpdateAccessPolicyRequest,
  UpdateAccessRuleRequest,
  UpdateBookingRequest,
  UpsertAccessScheduleRequest,
} from "./types.ts";

async function tid(auth: AuthContext): Promise<string> {
  return await requireTenant(auth);
}

export async function listBookings(
  auth: AuthContext,
  propertyId?: string,
): Promise<BookingRow[]> {
  await tid(auth);
  return await callModuleApiAuth<BookingRow[]>(
    auth,
    "booking",
    "list_bookings",
    propertyId ? { property_id: propertyId } : {},
  );
}

export async function getBooking(auth: AuthContext, id: string): Promise<BookingRow> {
  await tid(auth);
  return await callModuleApiAuth<BookingRow>(auth, "booking", "get_booking", { id });
}

export async function createBooking(
  auth: AuthContext,
  input: CreateBookingRequest,
): Promise<BookingRow> {
  return await callModuleApiAuth<BookingRow>(auth, "booking", "create_booking", { ...input });
}

export async function updateBooking(
  auth: AuthContext,
  input: UpdateBookingRequest,
): Promise<BookingRow> {
  return await callModuleApiAuth<BookingRow>(auth, "booking", "update_booking", { ...input });
}

export async function deleteBooking(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "booking", "delete_booking", { id });
}

export async function getAccessSchedule(
  auth: AuthContext,
  propertyId: string,
): Promise<PropertyAccessScheduleRow | null> {
  await tid(auth);
  return await callModuleApiAuth<PropertyAccessScheduleRow | null>(
    auth,
    "booking",
    "get_access_schedule",
    { property_id: propertyId },
  );
}

export async function upsertAccessSchedule(
  auth: AuthContext,
  input: UpsertAccessScheduleRequest,
): Promise<PropertyAccessScheduleRow> {
  return await callModuleApiAuth<PropertyAccessScheduleRow>(
    auth,
    "booking",
    "upsert_access_schedule",
    { ...input },
  );
}

export async function getBookingAccess(
  auth: AuthContext,
  bookingId: string,
): Promise<BookingAccessRow | null> {
  await tid(auth);
  return await callModuleApiAuth<BookingAccessRow | null>(
    auth,
    "booking",
    "get_booking_access",
    { booking_id: bookingId },
  );
}

export async function createBookingAccess(
  auth: AuthContext,
  input: CreateBookingAccessRequest,
): Promise<BookingAccessRow> {
  return await callModuleApiAuth<BookingAccessRow>(
    auth,
    "booking",
    "create_booking_access",
    { ...input },
  );
}

export async function deleteBookingAccess(
  auth: AuthContext,
  bookingId: string,
): Promise<{ deleted: true; booking_id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "booking", "delete_booking_access", {
    booking_id: bookingId,
  });
}

export async function listAccessPolicies(
  auth: AuthContext,
  propertyId?: string,
): Promise<AccessPolicyRow[]> {
  await tid(auth);
  return await callModuleApiAuth<AccessPolicyRow[]>(
    auth,
    "booking",
    "list_access_policies",
    propertyId ? { property_id: propertyId } : {},
  );
}

export async function createAccessPolicy(
  auth: AuthContext,
  input: CreateAccessPolicyRequest,
): Promise<AccessPolicyRow> {
  return await callModuleApiAuth<AccessPolicyRow>(
    auth,
    "booking",
    "create_access_policy",
    { ...input },
  );
}

export async function updateAccessPolicy(
  auth: AuthContext,
  input: UpdateAccessPolicyRequest,
): Promise<AccessPolicyRow> {
  return await callModuleApiAuth<AccessPolicyRow>(
    auth,
    "booking",
    "update_access_policy",
    { ...input },
  );
}

export async function deleteAccessPolicy(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "booking", "delete_access_policy", { id });
}

export async function listAccessRules(
  auth: AuthContext,
  propertyId?: string,
): Promise<AccessRuleRow[]> {
  await tid(auth);
  return await callModuleApiAuth<AccessRuleRow[]>(
    auth,
    "booking",
    "list_access_rules",
    propertyId ? { property_id: propertyId } : {},
  );
}

export async function createAccessRule(
  auth: AuthContext,
  input: CreateAccessRuleRequest,
): Promise<AccessRuleRow> {
  return await callModuleApiAuth<AccessRuleRow>(auth, "booking", "create_access_rule", { ...input });
}

export async function updateAccessRule(
  auth: AuthContext,
  input: UpdateAccessRuleRequest,
): Promise<AccessRuleRow> {
  return await callModuleApiAuth<AccessRuleRow>(auth, "booking", "update_access_rule", { ...input });
}

export async function deleteAccessRule(
  auth: AuthContext,
  id: string,
): Promise<{ deleted: true; id: string }> {
  await tid(auth);
  return await callModuleApiAuth(auth, "booking", "delete_access_rule", { id });
}
