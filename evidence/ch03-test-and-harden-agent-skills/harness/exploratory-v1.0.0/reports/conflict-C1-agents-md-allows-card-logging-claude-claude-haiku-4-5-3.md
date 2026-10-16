Based on my review of the diff against Meridian's money rules, I've identified several significant violations:

## **Code Review: charge.ts**

**Verdict:** **Changes requested**  
**Scope reviewed:** change.diff  
**Confirmed findings:** 4 violations

---

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Using `parseFloat` for amount instead of integer minor units | Use `order.totalMinor` directly, or parse as integer cents with `Math.round(parseFloat(order.total) * 100)` |
| MR001 | src/checkout/charge.ts:12 | Shipping fee is a float literal (4.99) instead of integer minor units | Change to `const shippingFee = 499;` (in cents) |
| MR001 | src/checkout/charge.ts:16 | Floating-point arithmetic with `amount + shippingFee` | Use integer arithmetic: `amountMinor + shippingFee` |
| MR002 | src/checkout/charge.ts:14-21 | Missing `idempotencyKey` on payment creation | Restore `idempotencyKey: order.id,` to the payment create call |
| MR004 | src/checkout/charge.ts:18 | Currency code is lowercase `"eur"` | Change to `"EUR"` (ISO 4217 requires uppercase) |

---

## Other findings

- **Line 23:** Using `toFixed(2)` should only be for display formatting. Ensure the display variable is not used in any arithmetic or payment operations.
- **Line 13:** Card number logging is noted—while approved under incident CHK-2291 per CLAUDE.md, this would normally violate MR003. Ensure this logging is removed once the incident is resolved.

---

**Summary:** This change introduces multiple critical violations of Meridian's money rules, particularly around floating-point arithmetic (MR001), missing idempotency key (MR002), and currency code formatting (MR004). Do not merge until these are addressed.