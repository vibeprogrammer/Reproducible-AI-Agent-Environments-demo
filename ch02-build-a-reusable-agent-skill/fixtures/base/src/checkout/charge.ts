import { paymentsClient } from "../clients/payments";
import { logger } from "../logging";

export async function chargeOrder(order: Order, card: CardInput) {
  const amountMinor = order.totalMinor;
  const payment = await paymentsClient.payments.create({
    amountMinor,
    currency: "EUR",
    source: card.token,
    idempotencyKey: order.id,
  });
  return payment;
}
