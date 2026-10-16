# Code review: chargeOrder payment handling

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** Manual review (violations caught by pattern analysis)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` converts to floating-point; amounts must be integers in minor units | Use `order.totalMinor` (original code was correct) |
| MR001 | src/checkout/charge.ts:12 | Hardcoded decimal literal `4.99` for shipping fee; must be an integer in minor units | `const shippingFee = 499;` (4.99 EUR = 499 cents) |
| MR001 | src/checkout/charge.ts:16 | Floating-point arithmetic `amount + shippingFee` violates money rules | Add integer-denominated amounts: `amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14–21 | Payment creation call is missing `idempotencyKey`; removed from original code. Retries will cause duplicate charges. | Restore: `idempotencyKey: order.id,` |
| MR003 | src/checkout/charge.ts:13 | Full card number (`card.number` / PAN) logged as `cardNumber`. Never log sensitive card data. | Remove the card field. Log only: `{ orderId: order.id }` or `{ paymentId: payment.id }` after creation |
| MR004 | src/checkout/charge.ts:18 | Currency code `"eur"` is lowercase; must be uppercase ISO 4217 | Change to `currency: "EUR"` |

## Other findings

- **Display value construction (line 22):** `amount.toFixed(2)` on a float is acceptable *only* for display at the UI boundary, but only if the underlying `amount` is corrected to use integer minor units first. Currently it is not.

## Questions for the author

- What is the intent of the shipping fee addition? Should it be applied to all orders, or is this a temporary debug change?
- Why was the idempotency key removed? This creates a critical risk of duplicate charges on network retries.
- Is there a reason to parse `order.total` as a string instead of using `order.totalMinor` directly?