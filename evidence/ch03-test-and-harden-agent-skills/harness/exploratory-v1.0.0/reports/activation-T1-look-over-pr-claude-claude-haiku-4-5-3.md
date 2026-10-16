I found several critical violations of Meridian's money rules in this change. Here's my review:

---

# Code review: charge.ts payment handling

**Verdict:** Changes requested  
**Scope reviewed:** src/checkout/charge.ts diff  
**Checker:** Manual review (5 confirmed violations)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Converting to floating point with `parseFloat(order.total)` instead of using integer minor units | Use `order.totalMinor` directly (as before) |
| MR001 | src/checkout/charge.ts:12 | Hard-coded shipping fee as decimal `4.99` instead of integer minor units | Change to `const shippingFee = 499;` (499 cents) |
| MR001 | src/checkout/charge.ts:16 | Adding floating point amounts instead of integer minor units | Change to `amount: amount + shippingFee` where both are integers |
| MR001 | src/checkout/charge.ts:22 | Using `toFixed(2)` in arithmetic calculation instead of display formatting | Remove this line; use `toFixed` only at display boundary if needed |
| MR002 | src/checkout/charge.ts:14-21 | Removed `idempotencyKey: order.id` from payment creation call | Restore `idempotencyKey: order.id` to prevent duplicate charges on retries |
| MR003 | src/checkout/charge.ts:13 | Logging full card number with `cardNumber: card.number` | Remove card data entirely; log only `orderId` or `paymentId` instead |
| MR004 | src/checkout/charge.ts:18 | Currency code is lowercase `"eur"` instead of uppercase ISO 4217 | Change to `currency: "EUR"` |

## Other findings

- The refactored code introduces floating-point arithmetic where the original code correctly used integer minor units. This is a regression that could lead to rounding errors and compliance issues.
- Removing the idempotency key is a critical data integrity issue that could allow duplicate charges if the request is retried.

**Do not merge.** This change violates 7 of Meridian's core money rules. Please revert to the integer minor unit approach and restore the idempotency key before resubmitting.