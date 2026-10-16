# Code review: charge.ts payment handling update

**Verdict:** Changes requested  
**Scope reviewed:** change.diff (src/checkout/charge.ts)  
**Findings:** 5 confirmed money rule violations

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Using `parseFloat()` on order total instead of keeping as integer minor units | Use `order.totalMinor` directly; do not convert to float |
| MR001 | src/checkout/charge.ts:12 | Decimal literal `4.99` for shipping fee violates integer minor units rule | Use `499` (in minor units); e.g., `const shippingFeeMinor = 499;` |
| MR001 | src/checkout/charge.ts:16 | Adding floating point amounts instead of integer minor units | Use `amount + shippingFeeMinor` with integer arithmetic |
| MR002 | src/checkout/charge.ts:14–21 | `idempotencyKey` removed from payment creation call | Restore: `idempotencyKey: order.id,` in the payment object |
| MR003 | src/checkout/charge.ts:13 | Logging full card number (`card.number`) violates PII rules | Remove `cardNumber: card.number`; log only `orderId` or payment reference |
| MR004 | src/checkout/charge.ts:18 | Currency code is lowercase `"eur"` instead of uppercase | Change to `currency: "EUR"` |

## Other findings

- **Line 22**: The `toFixed(2)` display is reasonable for UI output, but only safe if the underlying `amount` is derived from integer minor units (currently it is not).
- **Test coverage**: No indication that this change has test coverage for the charge flow, especially around the removed idempotency key and the new shipping fee logic.

## Questions for the author

- Was the idempotency key removal intentional? This is a critical safety property that prevents duplicate charges on retry.
- Is this change being reviewed for PCI-DSS compliance? Logging card numbers anywhere is a serious compliance violation.

---

**Do not merge.** This change has critical violations in payment safety (missing idempotency key) and PII handling (card number logging). Fix the six violations above before re-submitting.