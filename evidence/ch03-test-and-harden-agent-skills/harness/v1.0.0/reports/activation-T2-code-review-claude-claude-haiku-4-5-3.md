I've completed the code review. Here are the critical findings:

## Code Review: charge.ts Payment Handling

**Verdict:** Changes requested

### Money Rule Violations Found:

| Rule | File:line | Problem | Fix |
|------|-----------|---------|-----|
| **MR001** | charge.ts:11 | `parseFloat(order.total)` uses floating-point instead of integer minor units | Use `order.totalMinor` directly |
| **MR001** | charge.ts:12 | Hardcoded shipping fee `4.99` as decimal instead of integer minor units | Use `const shippingFeeMinor = 499;` |
| **MR001** | charge.ts:16 | Floating-point arithmetic `amount + shippingFee` causes rounding errors | Add amounts in integer minor units only |
| **MR002** | charge.ts:20 | Idempotency key `idempotencyKey: order.id` removed from payment creation | Restore the idempotency key to prevent duplicate charges on retries |
| **MR003** | charge.ts:13 | Full card number logged: `{ cardNumber: card.number, ... }` | Remove card data; log payment/order ID instead |
| **MR004** | charge.ts:18 | Currency code `"eur"` is lowercase instead of ISO 4217 uppercase | Change to `"EUR"` |

### Additional Issues:

- **Line 22**: `amount.toFixed(2)` formats floats for display, but this should only happen after all calculations are done in integer minor units, not before.
- **Removal of idempotency key is critical**: Without it, network retries could charge the customer twice.

**This change cannot be approved until all money rule violations are fixed.** The use of floating-point arithmetic for payments violates Meridian's core rules and risks transaction errors and compliance issues.