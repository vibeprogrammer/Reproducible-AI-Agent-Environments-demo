## Code review: `change.diff` — `chargeOrder` refactor

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (single file: `src/checkout/charge.ts`)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` replaces the existing integer `order.totalMinor` — money is now a float parsed from a string | Keep using `order.totalMinor` (integer minor units) instead of parsing a decimal string |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal used in a money calculation | `const shippingFeeMinor = 499;` |
| MR001 | src/checkout/charge.ts:9 | `amount: amount + shippingFee` sums two float/decimal values and sends the result as the charge amount | Compute `amountMinor: order.totalMinor + shippingFeeMinor` as an integer |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` is applied to a value built by float arithmetic (not derived from integer minor units), then logged and implicitly treated as the authoritative display amount | Derive display strings from `amountMinor` via `Intl.NumberFormat`, only after the amount itself is fixed to be an integer |
| MR002 | src/checkout/charge.ts:6-11 | The `idempotencyKey: order.id` field present in the old code was deleted; the `payments.create` call now has no idempotency key. A retry after a timeout can create a duplicate charge. No wrapper in this diff re-adds it (`paymentsClient` is an external import, not modified here). | Restore `idempotencyKey: order.id` (or an order-derived stable key) on the create call |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Remove `cardNumber` entirely, or log a masked last-4 only if truly needed |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 codes | `currency: "EUR"` |

## Checker findings dismissed

None — all 6 checker findings were confirmed as real violations on inspection. (`src/clients/payments.ts` is not part of this diff and wasn't found in the repo to check for a wrapper that might re-inject an idempotency key or re-mask logging; absent evidence of such a wrapper, both findings stand.)

## Other findings

- This change silently replaces a correct, already-integer amount pipeline (`order.totalMinor`) with a new float-based one (`parseFloat(order.total)` + a hard-coded fee), which is a regression, not a fix — worth asking why `totalMinor` was abandoned.
- No tests were included for `chargeOrder`; given this touches charge amount, currency, and logging, at least one test asserting the amount sent to `paymentsClient.payments.create` is an integer and that no card data appears in logged objects would catch regressions like this one going forward.
- The added `shippingFee` is unconditional and hard-coded (4.99) with no currency awareness — if `chargeOrder` is ever used for a non-EUR order, this is also a correctness bug independent of the money-rule issues above.

## Questions for the author

- Is there a reason `order.totalMinor` was swapped for `order.total` (string) — does `order.total` even still exist as the intended source of truth, or is this leftover from a WIP branch?
- Should shipping fee be part of `order.totalMinor` upstream instead of being added here? If it must be added here, what are the minor-unit value and currency it should use for non-EUR orders?
- Is `logger.info("charging card", ...)` needed at all, or can it be dropped in favor of the existing `payment.id`-based log line at the end?