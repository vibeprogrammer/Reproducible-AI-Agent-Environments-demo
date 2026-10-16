No existing test file for this function, confirming all 6 checker findings are real (no false positives to dismiss). Here's the review:

---

# Code review: checkout charge flow — amount/currency/logging changes

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | charge.ts:5 | `parseFloat(order.total)` reintroduces float arithmetic on money, replacing the existing integer `order.totalMinor` | Keep using `order.totalMinor` (integer minor units); don't parse a decimal string |
| MR001 | charge.ts:6 | `shippingFee = 4.99` is a decimal money literal | Use `shippingFeeMinor = 499` |
| MR001 | charge.ts:9 | `amount + shippingFee` sums a parsed float and a decimal literal, then sends that as the charge amount | Sum integer minor units: `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | charge.ts:8 | `idempotencyKey: order.id` was removed from the `payments.create()` call | Restore `idempotencyKey: order.id` on the create call |
| MR003 | charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Drop `cardNumber` entirely, or log a masked last-4 if a card reference is needed |
| MR004 | charge.ts:10 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 | Use `"EUR"` |

This diff also turns a `toFixed()`-formatted value into something that gets logged right next to the real charge (`display`), which is lower risk than the above but worth noting below.

## Checker findings dismissed

None — all 6 checker findings are confirmed violations (verified against `references/false-positives.md`; none are display-only `toFixed`, rate fields, keys set elsewhere, masked logs, or test data).

## Other findings

- **This is a regression, not a new feature.** The pre-diff code was correct on every one of these points (integer `totalMinor`, `"EUR"`, idempotency key present, no card logging). The diff actively removes those protections — worth flagging in review as "please explain why" rather than treating as an oversight in new code.
- `amount.toFixed(2)` at charge.ts:13 (`display`) is itself flagged as MR001 by the checker, but the real bug is upstream: `amount` was never integer minor units to begin with, so there's no clean "format for display" path here once amount/shippingFee are fixed.
- No test coverage included for `chargeOrder` (none exists in the repo currently either) — given this change touches amount calculation, currency, idempotency, and logging simultaneously, a unit test asserting the exact payload sent to `paymentsClient.payments.create()` would have caught all of MR001/MR002/MR004 mechanically.

## Questions for the author

- Why was `shippingFee` added as a separate line item instead of being folded into `order.totalMinor` upstream? If shipping is meant to vary, should it come from `order` as an integer field rather than a hard-coded `4.99` constant?
- Is `cardNumber` in the log intentional for a specific debugging need, or leftover from a local debug print? This needs to come out either way.