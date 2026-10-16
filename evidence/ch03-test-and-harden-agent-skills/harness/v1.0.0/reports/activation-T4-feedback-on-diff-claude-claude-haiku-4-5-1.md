## Code review: Checkout charge flow update

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  

### Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Converting amount to floating-point with `parseFloat(order.total)` instead of using integer minor units | Use `order.totalMinor` directly; do not convert to float |
| MR001 | src/checkout/charge.ts:12 | Hard-coded shipping fee as decimal literal `4.99` instead of integer minor units | Use integer minor units: `const shippingFee = 499;` (for cents) |
| MR002 | src/checkout/charge.ts:14-21 | Removed `idempotencyKey` from payment creation call | Add back `idempotencyKey: order.id,` to the create call |
| MR003 | src/checkout/charge.ts:13 | Logging full card number (`cardNumber: card.number`) which is PII | Log only `orderId` and `payment.id`, or use a masked last-4 |
| MR001 | src/checkout/charge.ts:16 | Arithmetic on floating-point amounts: `amount + shippingFee` | Compute with integer minor units: `order.totalMinor + shippingFee` |
| MR004 | src/checkout/charge.ts:18 | Currency code in lower case `"eur"` instead of ISO 4217 upper case | Use `"EUR"` |

### Other findings

- **Line 22-23:** The second logging call logs a formatted string, which is appropriate for display, but the underlying amount is already corrupted by floating-point arithmetic. If this is for diagnostics or audit trails, log the minor-unit amount with full precision instead.

### Summary

This change has **six critical violations** of Meridian's money rules. The main issues are:
1. Floating-point arithmetic instead of integer minor units (MR001)
2. Missing idempotency key on payment creation (MR002)  
3. Card number exposed in logs (MR003)
4. Lower-case currency code (MR004)

**Do not merge.** Revert to `order.totalMinor`, restore the idempotency key, add shipping in integer minor units, remove card data from logs, and use upper-case `"EUR"`.