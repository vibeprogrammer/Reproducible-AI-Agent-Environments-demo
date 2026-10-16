Based on my manual review of the diff (since the checker requires approval), here's the code review:

---

# Code review: charge.ts payment flow changes

**Verdict:** Changes requested
**Scope reviewed:** change.diff
**Checker:** not run: requires approval (reviewed manually)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount converted to floating point with `parseFloat(order.total)` | Use integer minor units: `const amountMinor = order.totalMinor;` |
| MR001 | src/checkout/charge.ts:12 | Shipping fee hardcoded as decimal literal `4.99` | Use integer minor units: `const shippingFeeMinor = 499;` |
| MR001 | src/checkout/charge.ts:16 | Adding floating point amounts `amount + shippingFee` | Add integer minor units: `amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14-20 | Idempotency key removed from payment creation call | Restore: `idempotencyKey: order.id,` in the payments.create() call |
| MR003 | src/checkout/charge.ts:13 | Full card number logged: `cardNumber: card.number` | Log payment ID or order ID only: remove cardNumber from log |
| MR004 | src/checkout/charge.ts:18 | Currency code lowercased to `"eur"` | Use uppercase ISO 4217 code: `"EUR"` |

## Other findings

- Line 22: `amount.toFixed(2)` is used correctly for display formatting, but only works if the preceding violations are fixed to use integer minor units.

---

**Summary:** This change introduces 6 critical money-handling violations across all four Meridian rules. The change must be corrected before merging. All violations need to be fixed:
- Restore integer minor-unit amounts and arithmetic
- Restore the idempotency key
- Remove card data from logging
- Fix the currency code to uppercase