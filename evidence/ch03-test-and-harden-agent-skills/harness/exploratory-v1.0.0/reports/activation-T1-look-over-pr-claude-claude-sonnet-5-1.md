All six checker findings check out on reading the code. Here's the review:

# Code review: chargeOrder — shipping fee + logging changes

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | charge.ts:11 | `parseFloat(order.total)` turns an integer-minor-units field into a float, reintroducing rounding error | Keep using `order.totalMinor` (integer cents) as the base amount |
| MR001 | charge.ts:12 | `shippingFee = 4.99` is a decimal float literal used in a money calculation | Use `shippingFeeMinor = 499` (integer cents) |
| MR001 | charge.ts:16 | `amount + shippingFee` is floating-point arithmetic on money (e.g. `0.1 + 0.2` style drift), and the field is no longer `amountMinor` | Compute `amountMinor = order.totalMinor + shippingFeeMinor` and pass that to `payments.create` |
| MR002 | charge.ts:14-21 | `idempotencyKey: order.id` was removed from the `payments.create` call | Restore `idempotencyKey: order.id` (or a more specific key if shipping fee creates a distinct charge) |
| MR003 | charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number (PII/card data) | Drop `cardNumber` entirely, or log a masked last-4 (e.g. `card.last4`) if needed for support |
| MR004 | charge.ts:17 | `currency: "eur"` is lower-case; ISO 4217 codes are upper-case | Use `currency: "EUR"` |

## Checker findings dismissed

None — all 6 checker findings are real violations.

## Other findings

- The added `display = amount.toFixed(2)` (line 22) is downstream of the now-floating `amount`, so once `amount` is fixed to be integer minor units, this formatting line needs to be reworked too (e.g. derive a display string from `amountMinor` via a minor-units-to-string formatter, not raw arithmetic on the float).
- No tests were included for the new shipping-fee behavior — worth adding a test asserting the total charged equals `order.totalMinor + shippingFeeMinor`.

## Questions for the author

- Is the `$4.99` shipping fee meant to be a hardcoded constant, or should it come from order/shipping config (in case it varies by region/carrier)?
- Should the idempotency key change now that the charge amount includes shipping (i.e., does a retry need to be distinguishable from a retry of the previous order-only amount)?

**Bottom line:** this diff reverts three of the four money rules that were previously satisfied (idempotency key, integer minor units, upper-case currency) and adds a new PII-logging issue. It needs rework before merging.