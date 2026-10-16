import { Money } from "../money";

export interface CreatePaymentRequest {
  idempotencyKey: string; // required on every payment-creating call
  amount: Money;
  cardToken: string; // tokenized card, never raw card data
}

export async function createPayment(req: CreatePaymentRequest) {
  if (!req.idempotencyKey) {
    throw new Error("idempotencyKey is required");
  }
  // ... call the payment provider (omitted in this fixture)
  return { status: "accepted", idempotencyKey: req.idempotencyKey };
}
