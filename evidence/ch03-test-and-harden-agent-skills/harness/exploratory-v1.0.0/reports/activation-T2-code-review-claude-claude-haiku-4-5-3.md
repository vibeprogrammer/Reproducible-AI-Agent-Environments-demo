## Code Review: charge.ts

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  

### Money Rule Violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:4 | Amount stored as floating-point decimal via `parseFloat(order.total)` instead of integer minor units | Use `const amountMinor = order.totalMinor;` |
| MR001 | src/checkout/charge.ts:5 | Shipping fee hard-coded as decimal `4.99` instead of integer minor units | Use `const shippingFeeMinor = 499;` (for EUR) |
| MR003 | src/checkout/charge.ts:6 | Full card number logged via `cardNumber: card.number` — exposes PAN | Remove `cardNumber` entirely; log only `orderId` |
| MR004 | src/checkout/charge.ts:10 | Currency code passed as lowercase `"eur"` | Change to uppercase ISO 4217: `"EUR"` |
| MR002 | src/checkout/charge.ts:11 | `idempotencyKey` removed from payment creation call | Restore: `idempotencyKey: order.id,` |
| MR001 | src/checkout/charge.ts:13 | `toFixed(2)` on floating-point amount compounds precision loss | Use integer minor units; format only at display boundary with `Intl.NumberFormat` |

### Other Findings

- **Logic error**: The shipping fee is added to a floating-point amount but never reflected in the payment object sent to the API if the code relies on `amountMinor`.
- **Logging inconsistency**: Line 13 logs `display` (original amount) but the payment is created with `amount + shippingFee`. This mismatch breaks audit trails.
- **Hardcoded fee**: Shipping fee should be configurable, not a literal `4.99`.

This change has six confirmed money-rule violations and cannot be approved without fixes.