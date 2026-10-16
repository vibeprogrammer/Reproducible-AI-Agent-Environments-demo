# Code review: charge.ts — shipping fee + logging changes

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** could not execute `scripts/check_money_rules.py` in this session (Bash denied); findings below are from manual inspection against `references/money-rules.md`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:14-19 | `idempotencyKey: order.id` is deleted from the `payments.create` call. A retry after a timeout can now create a duplicate charge. | Restore `idempotencyKey: order.id` (or a stable key derived from the order) on the create call. |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full PAN. | Drop `cardNumber` entirely, or log a masked last-4 only; never pass `card.number` to the logger. |
| MR001 | src/checkout/charge.ts:11-12 | `const amount = parseFloat(order.total)` and `const shippingFee = 4.99` introduce floating-point decimal amounts, replacing the integer `order.totalMinor`. | Keep amounts as integer minor units end-to-end, e.g. `const shippingFeeMinor = 499; const amountMinor = order.totalMinor + shippingFeeMinor;` |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` sends a floating-point major-unit amount to the payment create call instead of `amountMinor`. | Send `amountMinor: order.totalMinor + shippingFeeMinor` as in the original code. |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` lower-cases a previously-correct `"EUR"`. | Use the upper-case ISO 4217 code `"EUR"`. |

## Checker findings dismissed

- None — checker did not run; all findings above are from manual review, not auto-dismissed.

## Other findings

- `amount.toFixed(2)` at line 22 is only used for a log line (`display`), which would be fine as display-only formatting per the false-positives guide — but since `amount` itself is already a MR001 violation (not derived from integer minor units), this doesn't rescue the earlier issue.
- The combination of removing the idempotency key *and* switching to float arithmetic for a shipping fee is a large regression bundled into what looks like it should have been a small "add shipping fee" change — worth asking the author whether the logging/idempotency/currency-case changes were intentional or accidental collateral damage from a rebase/merge.
- No tests included for the new shipping-fee behavior.

## Questions for the author

- Was removing `idempotencyKey` intentional, or did it get dropped accidentally while editing the create-call object?
- Is `order.total` actually a string field on `Order`, or was this meant to stay `order.totalMinor` with a `shippingFeeMinor` integer added to it?
- Why does `currency` change from `"EUR"` to `"eur"` — was this an unintentional edit?