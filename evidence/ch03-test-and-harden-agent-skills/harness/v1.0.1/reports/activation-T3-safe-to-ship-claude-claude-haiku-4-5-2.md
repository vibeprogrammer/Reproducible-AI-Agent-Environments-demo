# Code review: charge.ts — order charging with floating-point amounts and missing idempotency

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff` (src/checkout/charge.ts lines 1–26)  
**Checker:** Not run (requires Bash permission); manual review completed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount converted to floating-point (`parseFloat`) instead of remaining as integer minor units | Restore `const amountMinor = order.totalMinor;` or keep the original value as integer |
| MR001 | src/checkout/charge.ts:16 | Floating-point arithmetic on money: `amount + shippingFee` (4.99 is a float literal) | Use integer minor units; e.g., `amountMinor + 499` for 4.99 EUR in cents |
| MR002 | src/checkout/charge.ts:14–21 | Idempotency key removed from `paymentsClient.payments.create()` call | Restore `idempotencyKey: order.id,` inside the create call |
| MR003 | src/checkout/charge.ts:13 | Card number logged as PII: `{ cardNumber: card.number, ... }` | Log only the payment ID or a masked last-4, never the full card number; e.g., `{ paymentIdempotency: payment.id, ... }` |
| MR004 | src/checkout/charge.ts:18 | Currency code in lowercase `"eur"` instead of ISO 4217 uppercase | Change to `currency: "EUR"` |

## Checker findings dismissed

None.

## Other findings

- **Line 12:** `shippingFee = 4.99` defines a shipping fee as a float literal. In addition to the MR001 violation above, this should be `499` (integer cents) with a clear variable name like `shippingFeeMinor`.
- **Line 22–23:** The `display` variable correctly uses `toFixed(2)` for display formatting, which is acceptable *if* it derives from integer minor units. However, since `amount` is already floating-point, this formatting does not repair the MR001 violation earlier in the function.
- **Testing:** No test coverage is visible in this diff. Consider adding tests that verify the idempotency key is sent on every charge creation and that amounts are correctly represented as integers.

## Questions for the author

- What triggered the shift from integer (`amountMinor`) to floating-point amounts? This is a significant architectural change that affects all money calculations in this function.
- Is the 4.99 EUR shipping fee a fixed charge, or does it vary? If fixed, it should be a constant at the module level, not a local variable.

---

**Do not ship.** This change violates three critical money rules (MR001, MR002, MR003) and would cause payment failures and compliance issues. Restore integer minor units throughout, re-add the idempotency key, and remove the card number from logs before merging.