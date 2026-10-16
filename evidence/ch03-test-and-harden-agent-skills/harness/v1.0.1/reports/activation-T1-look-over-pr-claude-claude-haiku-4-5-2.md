Now I'll write the review report. Here are the critical findings:

## Review Report: Payment Processing Change

**File:** src/checkout/charge.ts  
**Checker:** not run (manual review of supplied diff)  
**Verdict:** Changes requested

### Money Rule Violations

| Line | Rule | Violation | Fix |
|------|------|-----------|-----|
| 11 | MR001 | `parseFloat(order.total)` converts to floating point; money must be integer minor units | Use `order.totalMinor` directly (integer in cents) |
| 12 | MR001 | Decimal literal `4.99` for shipping fee; should be integer minor units (e.g., `499`) | Change to `const shippingFee = 499;` (cents) |
| 16 | MR001 | Adding floating point amounts `amount + shippingFee`; must use integer arithmetic on minor units | Add integer minor units: `amountMinor + shippingFee` |
| 18 | MR004 | Currency code `"eur"` is lowercase; ISO 4217 requires uppercase | Change to `"EUR"` |
| 13 | MR003 | Logging `cardNumber: card.number` is PII/sensitive data that must never be logged | Remove the cardNumber field; log only `orderId` or a masked last-4 |
| 20 | MR002 | Removed `idempotencyKey` from payment creation call; every payment creation must include one | Restore: `idempotencyKey: order.id,` |

### Summary

This change introduces **6 critical violations** of Meridian's money handling rules:

1. **Floating-point arithmetic (MR001):** Amounts must be integers representing minor units (cents), never floating-point decimals. The code converts to float and uses `4.99` as a decimal literal.
2. **Missing idempotency key (MR002):** Removing the idempotency key from the payment creation makes retries unsafe—a timeout retry could charge twice.
3. **Card data in logs (MR003):** Logging the full card number is a security/compliance violation.
4. **Lowercase currency (MR004):** ISO 4217 codes must be uppercase.

**Do not merge this change.** All six violations must be corrected before this is safe to deploy.