# Code review: charge.ts — floating-point amounts and missing idempotency key

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** Manual review against money rules

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Floating-point amount: `parseFloat(order.total)` instead of integer minor units | Restore `const amountMinor = order.totalMinor;` |
| MR001 | src/checkout/charge.ts:12 | Hardcoded floating-point shipping fee `4.99` instead of integer minor unit | Change to `const shippingFeeMinor = 499;` (or load from config as integer) |
| MR001 | src/checkout/charge.ts:16 | Payment amount passed as floating-point sum instead of integer | Change to `amountMinor: amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14–21 | Idempotency key removed from payment creation call | Add back `idempotencyKey: order.id` to the create call |
| MR003 | src/checkout/charge.ts:13 | Card number logged: `{ cardNumber: card.number, … }` — this is PII that must never be logged | Remove the card logging line entirely, or log only the payment ID |
| MR004 | src/checkout/charge.ts:18 | Currency code in lower case `"eur"` instead of ISO 4217 upper case | Change to `currency: "EUR"` |

## Other findings

- **Line 22:** `amount.toFixed(2)` creates a string from a floating-point number that should never exist. If display formatting is needed, format the original `amountMinor` using `Intl.NumberFormat` with the minor-unit divisor for EUR (100).

## Summary

**Do not ship.** This change violates all four money rules and introduces critical payment safety issues: floating-point arithmetic (precision and rounding errors), missing idempotency protection (risk of duplicate charges on retry), card data in logs (PII exposure), and incorrect currency format. Restore the original logic using integer minor units and the idempotency key, and remove card logging.