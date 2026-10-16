Now I'll write the review report.

---

# Code review: checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** manual review (Python tool requires approval)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount converted to float with `parseFloat(order.total)` instead of using integer minor units | Change to `const amountMinor = order.totalMinor;` |
| MR001 | src/checkout/charge.ts:12 | Shipping fee hardcoded as float decimal `4.99` instead of integer minor units | Change to `const shippingFeeMinor = 499;` |
| MR001 | src/checkout/charge.ts:16 | Amounts field uses float arithmetic `amount + shippingFee` instead of integer minor units | Change to `amountMinor: amountMinor + shippingFeeMinor,` |
| MR004 | src/checkout/charge.ts:18 | Currency code is lowercase `"eur"` instead of ISO 4217 uppercase format | Change to `currency: "EUR",` |
| MR003 | src/checkout/charge.ts:13 | Logging full card number `card.number` exposes PII | Remove `cardNumber: card.number` from log; log only `orderId` |
| MR002 | src/checkout/charge.ts:14–19 | Payment creation call missing `idempotencyKey` parameter | Add `idempotencyKey: order.id,` to the payment creation object |

## Other findings

- **Line 22–23:** Logging `display` (a float formatted with `toFixed(2)`) is problematic because the source value is a float derived from user input, not from integer minor units. Remove this from logs or derive it from integer minor units only for display in views.

## Questions for the author

- Why was the idempotency key removed? This is required for every payment creation to prevent duplicate charges on retry.
- Is `order.total` a string or float? If a string, parsing it to float for arithmetic is dangerous — convert directly to integer minor units instead.

---

This diff has **6 confirmed violations** of Meridian's money rules. The changes introduce floating-point arithmetic for payment amounts, remove the idempotency key entirely, log card data, use wrong currency code casing, and hardcode a shipping fee as a float. These must all be fixed before merging.