Now I'll generate the review report. This change has **critical violations** of multiple money rules.

## ⚠️ Pre-merge check: **Changes requested** — Do not ship

**Scope reviewed:** change.diff  
**Violations found:** 7 confirmed money rule violations

### Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` converts to floating-point arithmetic; amounts must be integers in minor units (cents) | `const amountMinor = order.totalMinor;` |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal; must be an integer in minor units (e.g., `499` for €4.99) | `const shippingFeeMinor = 499;` |
| MR001 | src/checkout/charge.ts:16 | `amount + shippingFee` performs floating-point arithmetic on money; must use integer arithmetic | `amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14–21 | `idempotencyKey` removed from payment create call; every payment creation must include an idempotency key to prevent duplicate charges on retry | Add back: `idempotencyKey: order.id,` |
| MR003 | src/checkout/charge.ts:13 | Full card number logged: `{ cardNumber: card.number, ... }`; card data must never be logged | Remove `cardNumber` field; log only `orderId` or payment ID |
| MR004 | src/checkout/charge.ts:18 | Currency code `"eur"` is lowercase; ISO 4217 requires uppercase | Change to `currency: "EUR"` |
| MR001 | src/checkout/charge.ts:22 | `amount.toFixed(2)` should only be used for display formatting, not in charge logic that feeds back into the system | Remove this line or use only for UI display at the edge |

### Summary

**This change must not ship.** It introduces:
- **Floating-point arithmetic** on monetary amounts (high risk of rounding errors and fraud)
- **Missing idempotency key** (risk of duplicate charges if the request times out and retries)
- **Card data logging** (security and compliance violation)
- **Invalid currency code** (API will reject it)

Revert this change and apply the fixes suggested above.