# Code review: `chargeOrder` switches to float amount and shipping fee

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR003 | src/checkout/charge.ts:7 | Logs the raw card PAN: `logger.info("charging card", { cardNumber: card.number, ... })` | Remove `cardNumber` entirely, or log a masked last-4 if a reference is needed |
| MR002 | src/checkout/charge.ts:8-11 | The previous `idempotencyKey: order.id` was deleted from the `payments.create` call; a timeout-triggered retry can now double-charge the customer | Restore `idempotencyKey: order.id` (or an equivalent stable key) on the create call |
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` converts the amount to a float and feeds it straight into the charge; `order.totalMinor` (already an integer) was dropped | Keep using `order.totalMinor`; don't parse a decimal string for the charge amount |
| MR001 | src/checkout/charge.ts:6,9 | `shippingFee = 4.99` is a decimal literal added to the charge (`amount + shippingFee`); floating-point addition on money can misround totals | Express the fee in minor units, e.g. `shippingFeeMinor = 499`, and add it to `amountMinor` |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 | `currency: "EUR"` |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` formats a value that never came from minor units (it's the parsed float from MR001 above), so this isn't the display-only case the false-positive guide allows | Derive the display string from `amountMinor` (e.g. `(amountMinor / 100).toFixed(2)`), or drop this log line |

## Checker findings dismissed

None — all 6 checker findings confirmed as real violations.

## Other findings

- The whole rewrite silently drops the integer `totalMinor` path for a string-parsing one with no apparent reason given in the diff — worth asking why, since it reintroduces float arithmetic that `totalMinor` existed to avoid.
- No tests were added/updated for this change in the diff; given it touches both the charge amount and the idempotency key, it should have coverage for a retry-doesn't-double-charge case.

## Questions for the author

- Why switch from `order.totalMinor` to `parseFloat(order.total)` at all? If `totalMinor` is still available on `Order`, this looks like an accidental revert rather than an intentional change.
- Was dropping `idempotencyKey` intentional, or is it meant to be re-added by a wrapper not shown in this diff? I found no evidence of that in the repo.

**Bottom line: not safe to ship as-is.** This introduces a real double-charge risk (missing idempotency key), logs a raw card number, and reintroduces float arithmetic + a lower-case currency code — four independent regressions on money/PII rules in one small diff.