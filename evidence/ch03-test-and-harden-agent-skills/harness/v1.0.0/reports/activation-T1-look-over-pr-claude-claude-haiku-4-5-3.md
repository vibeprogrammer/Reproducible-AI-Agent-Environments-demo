Based on my review of the diff, I found **5 critical violations** of Meridian's money rules:

---

# Code review: Checkout charge function

**Verdict:** ⛔ Changes requested
**Scope reviewed:** change.diff
**Violations found:** 5 money rule violations

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount converted to float instead of using integer minor units | Keep `const amountMinor = order.totalMinor;` and use `amountMinor` throughout |
| MR001 | src/checkout/charge.ts:12 | Shipping fee hardcoded as float (4.99) instead of integer minor units | Use integer: `const shippingFee = 499;` (in cents/ore) |
| MR002 | src/checkout/charge.ts:14-19 | Idempotency key removed from payment creation | Add back `idempotencyKey: order.id,` in the payment request |
| MR003 | src/checkout/charge.ts:13 | Card number logged as PII | Remove `cardNumber: card.number` from the log; log only `orderId` or payment ID |
| MR004 | src/checkout/charge.ts:18 | Currency code not ISO 4217 uppercase | Change `"eur"` to `"EUR"` |

## Other findings

- Floating point arithmetic on amounts (line 16: `amount + shippingFee`) will cause precision errors
- The `display` variable for logging (line 22) is built from the float amount, so the underlying data is still wrong

**Do not merge this change.** These violations expose the system to floating-point rounding errors in payments and create PII leaks in logs.