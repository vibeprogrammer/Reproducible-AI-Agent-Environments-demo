Based on my review of the diff against Meridian's money rules, I've identified several critical violations. Let me write the report:

# Code review: chargeOrder payment change

**Verdict:** Changes requested
**Scope reviewed:** change.diff
**Checker:** Manual review (critical violations detected)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount parsed as floating-point decimal instead of integer minor units | Use `order.totalMinor` directly, or multiply `order.total` by 100 and round to an integer |
| MR001 | src/checkout/charge.ts:12 | Shipping fee is a decimal literal (4.99) instead of integer minor units | Use `499` (in cents) instead of `4.99` |
| MR001 | src/checkout/charge.ts:16 | Arithmetic performed on floating-point amounts | Change to: `amount: order.totalMinor + 499` (both in minor units) |
| MR001 | src/checkout/charge.ts:23 | `toFixed(2)` used for logging, not display formatting | Remove this line or move to display layer; log the integer `amount` instead |
| MR002 | src/checkout/charge.ts:14–21 | Idempotency key removed from payment creation call | Restore: `idempotencyKey: order.id,` |
| MR003 | src/checkout/charge.ts:13 | Card number logged as PII | Remove `cardNumber: card.number` from the log; use `cardToken: card.token` or omit card info entirely |
| MR004 | src/checkout/charge.ts:18 | Currency code in lowercase instead of uppercase ISO 4217 | Change `"eur"` to `"EUR"` |

## Summary

**Do not merge this change.** It violates four of Meridian's five core money rules and introduces serious data-protection and payment-safety issues:

- Floating-point arithmetic will cause rounding errors in money calculations
- Missing idempotency key creates risk of duplicate charges on retry
- Logging the card number is a PCI compliance violation
- Lowercase currency code will be rejected by the payments API

Please revert and fix all violations before resubmitting.