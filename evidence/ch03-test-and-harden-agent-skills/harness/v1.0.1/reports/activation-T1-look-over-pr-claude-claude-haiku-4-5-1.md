Based on my analysis of the diff against Meridian's money rules, I found several critical violations. Here's the review:

---

# Code review: charge.ts payment processing

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** Not run (manual review of money rules)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Using `parseFloat()` converts to decimal; money must be integer minor units | Use `order.totalMinor` (integer cents/ore) instead |
| MR001 | src/checkout/charge.ts:12 | Hardcoded decimal literal `4.99` in shipping fee; must be integer minor units | Use `499` (minor units) instead |
| MR001 | src/checkout/charge.ts:16 | Floating-point arithmetic `amount + shippingFee` causes precision errors | Add amounts as integers: `amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14-17 | `idempotencyKey` removed from payment creation call | Restore `idempotencyKey: order.id` in the create call |
| MR003 | src/checkout/charge.ts:13 | Card number logged in `{ cardNumber: card.number }` — PII must never be logged | Remove card.number; log `paymentId` or masked last-4 instead |
| MR004 | src/checkout/charge.ts:18 | Currency code `"eur"` is lowercase; ISO 4217 requires uppercase | Change to `"EUR"` |

## Other findings

- The reversion from `order.totalMinor` to `order.total` loses type safety and semantic clarity about the amount representation.
- Adding a fixed `4.99` shipping fee with no configuration or input validation is a design concern (though not a money rule issue).

## Questions for the author

- Why was the idempotency key removed? This is a critical safety mechanism.
- Is there a reason to use floating-point amounts instead of the original integer minor units approach?

---

**Do not merge this PR** until all money rule violations (MR001–MR004) are addressed. The issues with floating-point arithmetic, missing idempotency key, and logged card data are critical for payment safety and security.