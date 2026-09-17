import { type AuthContext, requireTenant } from "../shared/auth.ts";
import { callModuleApiAuth } from "../shared/edge-rpc.ts";
import type {
  CancelPaymentRequest,
  CreateCheckoutSessionRequest,
  PaymentEventRow,
  PaymentIntentRow,
} from "./types.ts";

async function tid(auth: AuthContext): Promise<string> {
  return await requireTenant(auth);
}

export async function createCheckoutSession(
  auth: AuthContext,
  input: CreateCheckoutSessionRequest,
): Promise<PaymentIntentRow> {
  return await callModuleApiAuth<PaymentIntentRow>(
    auth,
    "payment",
    "create_checkout_session",
    { ...input },
  );
}

export async function getPayment(auth: AuthContext, id: string): Promise<PaymentIntentRow> {
  await tid(auth);
  return await callModuleApiAuth<PaymentIntentRow>(auth, "payment", "get_payment", { id });
}

export async function listPayments(
  auth: AuthContext,
  filters?: { status?: string; target_type?: string; target_id?: string },
): Promise<PaymentIntentRow[]> {
  await tid(auth);
  return await callModuleApiAuth<PaymentIntentRow[]>(
    auth,
    "payment",
    "list_payments",
    filters ?? {},
  );
}

export async function cancelPayment(
  auth: AuthContext,
  input: CancelPaymentRequest,
): Promise<PaymentIntentRow> {
  return await callModuleApiAuth<PaymentIntentRow>(auth, "payment", "cancel_payment", { ...input });
}

export async function paymentHistory(
  auth: AuthContext,
  paymentIntentId: string,
): Promise<PaymentEventRow[]> {
  await tid(auth);
  return await callModuleApiAuth<PaymentEventRow[]>(auth, "payment", "payment_history", {
    payment_intent_id: paymentIntentId,
  });
}
