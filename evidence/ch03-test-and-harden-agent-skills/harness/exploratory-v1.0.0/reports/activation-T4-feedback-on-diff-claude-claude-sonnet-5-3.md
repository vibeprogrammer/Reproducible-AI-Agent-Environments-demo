All 6 checker findings are confirmed real on inspection. Here's the review.

# Code review: checkout charge flow

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | charge.ts:11 | `parseFloat(order.total)` converts money to a float instead of using the existing integer minor-unit field | Keep `order.totalMinor` (an integer) instead of re-deriving from a decimal string |
| MR001 | charge.ts:12 | `shippingFee = 4.99` is a decimal literal added directly to a money amount | Use `shippingFeeMinor = 499` and add to `amountMinor` |
| MR001 | charge.ts:16 | `amount: amount + shippingFee` sends a float dollar amount to the payment API instead of integer minor units — this also silently changes the API field from `amountMinor` to `amount`, so the provider will likely receive the wrong magnitude/type entirely | Compute `amountMinor: order.totalMinor + shippingFeeMinor` and keep the `amountMinor` field name |
| MR002 | charge.ts:14-20 | `idempotencyKey: order.id` was **removed** from the `payments.create` call — a retry after a timeout can now create a duplicate charge | Restore `idempotencyKey: order.id` (or a key derived from the order) |
| MR003 | charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Drop `cardNumber`; log `orderId` only, or a masked last-4 if needed |
| MR004 | charge.ts:17 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 | Use `"EUR"` |

## Checker findings dismissed

None — all 6 checker findings are real violations.

## Other findings

- The combination of MR001 + MR002 is the most serious issue: this diff changes a correct, minor-unit, idempotent charge call into one that (a) sends a decimal float amount under a differently-named field (`amount` vs `amountMinor`) and (b) has no idempotency key. Depending on how lenient `paymentsClient` is, this could either throw, silently charge the wrong amount (e.g. cents vs dollars confusion), or double-charge on retry.
- `display = amount.toFixed(2)` at line 22 is only used for a log line, which is a legitimate display use per MR001 — but it's downstream of the already-corrupted `amount` float, so it's moot once `amount`/`shippingFee` are fixed to integer minor units.
- No tests were included for the new shipping-fee behavior; given the amount-calculation bug above, a test asserting the exact `amountMinor` sent to `paymentsClient.payments.create` would have caught this.

## Questions for the author

- Is `order.total` (string, decimal) actually populated and intended to replace `order.totalMinor`, or is this a leftover from an earlier draft? The existing field (`order.totalMinor`) looks like it should still be the source of truth.
- Is the shipping fee supposed to vary by order (e.g., by weight/destination), or is `4.99` intentionally a flat global constant? If the latter, it should still live as a named `SHIPPING_FEE_MINOR` constant in minor units, not inline here.