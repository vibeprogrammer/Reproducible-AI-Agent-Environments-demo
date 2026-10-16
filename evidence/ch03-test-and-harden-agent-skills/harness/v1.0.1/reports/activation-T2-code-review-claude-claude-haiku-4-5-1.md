I don't have permission to run the checker script. Let me review the diff manually against Meridian's money rules.

Looking at the change in `src/checkout/charge.ts`, I've identified several violations:

**Money Rule Violations Found:**

| Line | Rule | Issue | Fix |
|------|------|-------|-----|
| 11 | MR001 | Using `parseFloat(order.total)` creates a floating-point amount instead of integer minor units | Use `order.totalMinor` (the original code was correct) |
| 12 | MR001 | Hardcoded `shippingFee` as `4.99` (float) instead of integer minor units (e.g., `499` for cents) | Change to `const shippingFee = 499;` (integer minor units) |
| 13 | MR003 | Logging `cardNumber: card.number` exposes card data (PII) | Remove this field from the log, or log a masked value like `lastFour: card.number.slice(-4)` |
| 16 | MR001 | Computing `amount + shippingFee` with floating-point values violates integer minor unit rule | Add integers instead: `amountMinor + shippingFee` |
| 18 | MR004 | Currency code `"eur"` is lowercase; ISO 4217 requires uppercase | Change to `"EUR"` |
| 20 | MR002 | Removed `idempotencyKey` from payment creation call | Restore it: `idempotencyKey: order.id` |
| 22 | MR001 | Using `toFixed(2)` still doesn't fix the underlying float issue; display purposes should never drive data types | Remove this line or use it only for display after proper integer handling |

**Verdict: Changes requested**

This change violates four critical money rules (MR001, MR002, MR003, MR004). The original code was handling amounts correctly as integer minor units with proper idempotency. The new code converts to floating-point arithmetic, removes idempotency protection, logs card data, and uses incorrect currency formatting. These must be fixed before merging.