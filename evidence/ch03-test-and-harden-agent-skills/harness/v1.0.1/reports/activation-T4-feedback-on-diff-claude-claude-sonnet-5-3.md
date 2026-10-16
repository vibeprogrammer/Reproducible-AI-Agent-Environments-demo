No test file exists for this flow. Here's the review.

# Code review: checkout charge flow

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:20 (removed) | `idempotencyKey: order.id` was deleted from the `payments.create` call. A retry after a network timeout can now double-charge the customer. | Restore `idempotencyKey: order.id` (or another stable, order-derived key) on the create call. |
| MR001 | src/checkout/charge.ts:5 | `order.totalMinor` (an integer) was replaced with `parseFloat(order.total)`, reintroducing floating-point money. | Keep using `order.totalMinor` and do all arithmetic in integer minor units. |
| MR001 | src/checkout/charge.ts:6 | `const shippingFee = 4.99;` is a decimal literal money value. | Use `const shippingFeeMinor = 499;` and add in minor units. |
| MR001 | src/checkout/charge.ts:9 | `amount: amount + shippingFee` sends a floating-point sum as the charge amount to the payments client, replacing the prior `amountMinor`. | Send `amountMinor: order.totalMinor + shippingFeeMinor`. |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` formats the floating-point `amount`, not a value derived from integer minor units, so this isn't safe display formatting (see false-positives guidance — only exempt when the source value is minor-units-derived). | Derive the display string from `amountMinor` (e.g. `Intl.NumberFormat` dividing by the currency's minor-unit factor), not from the float. |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the raw card number (PAN). | Drop `cardNumber` entirely, or log a masked last-4 only. |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` — lower-case, not a valid ISO 4217 code at the API boundary. | Use `currency: "EUR"`. |

## Checker findings dismissed

None.

## Other findings

- The diff removes `amountMinor` and the idempotency key in the same change that adds `shippingFee` — it reads like "add shipping fee to the charge" accidentally reverted unrelated, already-correct code. Worth checking whether this was based on a stale branch.
- No test file exists for this flow (`src/checkout/charge.ts` has no corresponding test), so none of these regressions (double-charge risk, float rounding, PII logging) would be caught by CI. Worth adding a test asserting `payments.create` is called with an integer `amountMinor`, uppercase `currency`, and a non-empty `idempotencyKey`, plus a test asserting the logger output never contains a card number.
- The second `logger.info("charged", { paymentId: payment.id, display })` call itself is fine (no PII) — it's only tainted by `display` carrying a float-derived value (see MR001 above).

## Questions for the author

- Is `order.total` (string) still needed anywhere, or can it be removed now that `order.totalMinor` is available? If `order.total` is a legacy/display-only field, consider deprecating it to prevent this mistake from recurring.
- Was the shipping fee meant to be looked up per-currency/region rather than hard-coded at `4.99`? Hard-coding also assumes EUR-style two-decimal minor units, which breaks for currencies like JPY.

---

This diff net-removes two of the safeguards that were already in place (`amountMinor`, `idempotencyKey`) while adding a card-number log line — I'd block this from merging until those are restored and the card logging is removed.