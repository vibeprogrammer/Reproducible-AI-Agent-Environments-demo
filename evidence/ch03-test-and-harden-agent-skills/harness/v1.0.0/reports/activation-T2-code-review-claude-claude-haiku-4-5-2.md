Here's the code review of change.diff:

---

# Code review: chargeOrder payment handling

**Verdict:** Changes requested  
**Scope reviewed:** change.diff (src/checkout/charge.ts)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| **MR001** | src/checkout/charge.ts:11 | Using `parseFloat(order.total)` for money amount; amounts must be integers in minor units (cents) | Change to `const amountMinor = order.totalMinor;` |
| **MR001** | src/checkout/charge.ts:12 | Hard-coded floating-point shipping fee `4.99`; amounts must be integers in minor units | Change to `const shippingFeeMinor = 499;` (for EUR cents) |
| **MR001** | src/checkout/charge.ts:16 | Floating-point arithmetic `amount + shippingFee` on money; use integer arithmetic on minor units | Change to `amountMinor: amountMinor + shippingFeeMinor` |
| **MR002** | src/checkout/charge.ts:20 | Removed `idempotencyKey: order.id` from payment creation call; idempotency keys prevent duplicate charges on retry | Restore `idempotencyKey: order.id,` in the payment object |
| **MR003** | src/checkout/charge.ts:13 | Logging full card number in `{ cardNumber: card.number }`; card data is PII and must never be logged | Remove `cardNumber` field; log `paymentId` or a masked last-4 instead |
| **MR004** | src/checkout/charge.ts:18 | Currency code is lowercase `"eur"`; ISO 4217 codes must be uppercase | Change to `currency: "EUR"` |

## Other findings

- **Unused variable:** The `display` variable on line 22 is calculated with `toFixed(2)` but never used. Remove it or clarify the intent.
- **Inconsistent logging patterns:** The first log statement (line 13) breaks MR003; the second (line 23) is better-formed. After fixing the card data issue, consolidate if both logs aren't needed.

---

**This change cannot be approved in its current form.** It introduces six critical violations of Meridian's money handling rules, including floating-point arithmetic on amounts, missing idempotency key, PII logging, and currency code formatting. These must be fixed before merging.