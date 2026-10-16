All 6 checker findings check out against the actual diff — this PR takes working, compliant code and regresses it on every money rule. Here's the report.

# Code review: chargeOrder refactor

**Verdict:** Changes requested
**Scope reviewed:** change.diff (`src/checkout/charge.ts`)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` replaces the existing integer `order.totalMinor`, reintroducing float arithmetic on money | Keep using `order.totalMinor` (integer minor units) |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal used in a money calculation | Use an integer minor-unit constant, e.g. `shippingFeeMinor = 499` |
| MR001 | src/checkout/charge.ts:16 | `amount + shippingFee` is float addition on money, and `amount` is a non-integer field name sent to the payments client (was `amountMinor`) | Compute `amountMinor = order.totalMinor + shippingFeeMinor` and pass that |
| MR002 | src/checkout/charge.ts:14-21 | `idempotencyKey: order.id` was removed from the `payments.create` call entirely | Restore `idempotencyKey: order.id` (or another stable key derived from the order) |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number | Drop `cardNumber` from the log, or log only a masked last-4 if traceability is needed |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; ISO 4217 codes are upper-case | Use `"EUR"` |

## Checker findings dismissed

None — all 6 checker findings are confirmed real violations on inspection of the diff and the current (pre-change) file.

## Other findings

- `amount.toFixed(2)` (line 22) is used only for a log message after the float computation above, so it's downstream of the MR001 violation rather than a separate issue — fixing the amount to integer minor units removes the need for `toFixed` here too.
- The diff removes the `amountMinor` field name but `paymentsClient.payments.create` likely still types/expects `amountMinor`; this change would probably also fail type-checking, not just the money-rules review.
- No tests were included with this change; given it touches charge creation, currency, and idempotency, it should have test coverage for the amount calculation and the idempotency key at minimum.

## Questions for the author

- What's the motivation for switching from `order.totalMinor` to `parseFloat(order.total)` plus a hard-coded shipping fee — is `totalMinor` missing the shipping amount upstream, and if so, should that be fixed at the order level instead of here?
- Is the `cardNumber` logging intentional for debugging, and if so, can it be replaced with a masked value or removed before merge?

This diff takes compliant code and reverts it on MR001, MR002, MR003, and MR004 simultaneously — I'd block the merge until these are fixed.