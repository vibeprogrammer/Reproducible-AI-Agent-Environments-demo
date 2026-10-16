## Code review: charge.ts payment handling

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** not run (manual review)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Using `parseFloat(order.total)` for monetary arithmetic instead of integer minor units | Use `order.totalMinor` directly as an integer |
| MR001 | src/checkout/charge.ts:12 | Decimal literal `4.99` used for shipping fee instead of integer minor units | Use `499` (or appropriate minor unit count) |
| MR001 | src/checkout/charge.ts:16 | Arithmetic on floating-point amounts: `amount + shippingFee` is unsafe for money | Compute shipping as integer minor units, then add to `amountMinor` |
| MR002 | src/checkout/charge.ts:14-21 | `idempotencyKey` removed from payment creation call | Restore `idempotencyKey: order.id` in the payment creation parameters |
| MR004 | src/checkout/charge.ts:18 | Currency code `"eur"` is lowercase; must be uppercase ISO 4217 | Change to `"EUR"` |

## Other findings

- Line 22: `amount.toFixed(2)` converts a float to a display string, which is brittle when the source is a `parseFloat` result. This should format the integer minor units properly (e.g., `amountMinor / 100` formatted via `Intl.NumberFormat`).

**Do not merge.** This change introduces five violations of Meridian's money rules. The most critical are the missing idempotency key (MR002—creates a retry vulnerability) and floating-point arithmetic (MR001—causes rounding errors in payments).