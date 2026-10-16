All 6 checker findings are genuine (none are false positives per the skill's guide — no masking, no display-of-minor-units case, no test context). Here's the report:

# Code review: chargeOrder — amount parsing, shipping fee, and logging changes

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` turns an integer minor-units amount into a float; the whole downstream calculation (`amount + shippingFee`, `toFixed`) is now float arithmetic on money | Use `order.totalMinor` directly, as the old code did |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal added straight into the charged amount | Use an integer minor-units constant, e.g. `shippingFeeMinor = 499` |
| MR002 | src/checkout/charge.ts:8 | `paymentsClient.payments.create(...)` no longer sends `idempotencyKey` — the old code had `idempotencyKey: order.id` and it was dropped. A retry after a network timeout can now double-charge the customer | Restore `idempotencyKey: order.id` (or another value stable per order) in the create call |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card/PAN | Drop `cardNumber` entirely, or log a masked last-4 if it's needed for support |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 | Use `"EUR"` |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` for the `display` field — not a new violation by itself (formatting for display/logging is fine), but `amount` is already the tainted float from line 5, so this log line will show incorrect values once minor units are restored | Resolves automatically once `amount`/`amount + shippingFee` are replaced with an integer minor-units total; derive `display` from that integer via proper minor-unit formatting (don't divide/multiply by a hard-coded 100 for every currency) |

## Checker findings dismissed

None — all 6 checker findings confirmed as real violations.

## Other findings

- **Silent business-logic change:** the diff adds a hard-coded €4.99 shipping fee inside `chargeOrder` that wasn't there before. If this is intentional, it probably belongs in `order.totalMinor` (computed upstream, inclusive of shipping) rather than bolted on at charge time with a magic number — as written, every order gets charged an extra flat shipping fee regardless of its actual shipping cost.
- **Currency hard-coded:** `currency: "EUR"`/`"eur"` was already hard-coded before this diff and remains so; not introduced by this change, but worth flagging if Meridian processes non-EUR orders.
- **No tests:** the diff doesn't touch or add tests for `chargeOrder`, despite changing the amount calculation, dropping idempotency, and changing what's logged — all behavior-changing and risk-bearing.

## Questions for the author

- Is the `shippingFee` addition intentional for this change, or did it get mixed in from another branch? The commit removes `idempotencyKey` with no apparent replacement — was that intentional or an accidental deletion during a rebase/merge?
- Does `order.total` (string) still exist as a field, or should this have read `order.totalMinor` as before? The switch to `parseFloat(order.total)` looks like a straight regression from the prior integer-minor-units approach.