All six checker findings are real violations (confirmed against `money-rules.md` and `false-positives.md` — none qualify for dismissal). Here's the review:

# Code review: `chargeOrder` — broken money handling in checkout charge path

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `order.totalMinor` (integer minor units) is replaced with `parseFloat(order.total)`, parsing a decimal string into a float for arithmetic | Keep using `order.totalMinor` as an integer; do not reintroduce string/float parsing of money |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal fed into the charge amount | Express as `shippingFeeMinor = 499` (integer cents) |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` is applied to a value that was never integer minor units (it came from `parseFloat`), then logged — this is float arithmetic masquerading as display formatting, not safe display of an integer-derived value | Remove once `amount`/`amountMinor` is fixed to be an integer; format for display with `Intl.NumberFormat` only, never `toFixed` |
| MR002 | src/checkout/charge.ts:8-11 | The `idempotencyKey: order.id` that existed on `paymentsClient.payments.create(...)` was deleted. A retry after a network timeout can now create a duplicate charge | Restore `idempotencyKey: order.id` (or another stable, order-derived key) on the create call |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN) | Drop `cardNumber` entirely, or log a masked last-4 if a card reference is needed |
| MR004 | src/checkout/charge.ts:10 | Currency changed from `"EUR"` to lower-case `"eur"` | Use the upper-case ISO 4217 code `"EUR"` |

## Checker findings dismissed

None.

## Other findings

- **Field rename breaks the API contract, not just the money format.** The diff also renames the field sent to `paymentsClient.payments.create` from `amountMinor` to `amount` (src/checkout/charge.ts:14-16). Even after fixing MR001, this field name mismatch would likely fail type-checking or silently send the wrong parameter to the payments client — the field name should stay `amountMinor`.
- **Net effect of this diff is a regression on every axis**, not a partial improvement: it takes working, compliant code (integer minor units, idempotency key, upper-case currency, no card logging) and reintroduces float math, drops the idempotency key, lower-cases the currency, and adds a card-number log line. This reads like it should be rejected wholesale rather than patched piecemeal.
- No tests accompany this change (none exist in the repo for `chargeOrder` either before or after), so none of these regressions would be caught by CI.

## Questions for the author

- What motivated this change? The diff removes correct money-handling code rather than building on it — was this an accidental revert, or is there a requirement (e.g., a new `order.total`/string-based API) driving the switch away from `totalMinor`?