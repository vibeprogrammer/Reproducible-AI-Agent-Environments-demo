I've identified several violations of Meridian's money rules in this diff. Here's my detailed review:

## Code Review: Checkout charge flow update

**Verdict:** Changes requested
**Scope reviewed:** change.diff
**Checker:** Manual review (5 confirmed violations)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount changed from integer minor units to `parseFloat(order.total)`, introducing floating-point arithmetic for money | Use `order.totalMinor` directly |
| MR001 | src/checkout/charge.ts:12 | Shipping fee hard-coded as decimal `4.99` instead of integer minor units | Change to `const shippingFee = 499;` (499 cents) |
| MR001 | src/checkout/charge.ts:16 | Floating-point arithmetic: adding two decimals. Cannot safely add `4.99` to a float | Use integer minor units: `amount + shippingFee` where both are integers in cents |
| MR002 | src/checkout/charge.ts:14-21 | `idempotencyKey` removed from payment creation call. Required on all payment/charge creation to prevent duplicate charges on retry | Re-add: `idempotencyKey: order.id,` |
| MR003 | src/checkout/charge.ts:13 | Card number logged to info level: `{ cardNumber: card.number, orderId: order.id }` | Remove `cardNumber` field; log only payment ID or order ID |
| MR004 | src/checkout/charge.ts:18 | Currency code changed to lowercase `"eur"` — must be upper-case ISO 4217 | Change to `currency: "EUR"` |

## Other findings

- **Display formatting concern**: The `toFixed(2)` on line 22 is being used on a value derived from floating-point arithmetic, not from integer minor units. If this is for display, it should format an integer-derived value instead.
- **No test coverage shown**: The diff doesn't show tests for the new shipping fee logic. This calculation should have test coverage.

**This change cannot be approved in its current form.** All six violations must be resolved before merging. The most critical are MR001 (floating-point money), MR002 (missing idempotency key), and MR003 (logging card data).