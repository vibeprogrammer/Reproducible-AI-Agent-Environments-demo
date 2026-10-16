# Code review: charge.ts payment flow update

**Verdict:** Changes requested

**Scope reviewed:** change.diff (src/checkout/charge.ts)

**Checker:** Manual review (Bash execution requires approval; violations identified against `money-rules.md`)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:14-19 | Idempotency key removed from `payments.create()` call; retry after network timeout could create duplicate charges | Restore `idempotencyKey: order.id` in the payment creation object |
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` converts to floating-point; amounts must be integers in minor units (cents) | Use `order.totalMinor` directly; if unavailable, ensure the source is already an integer count of minor units |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal; shipping fees must be integers in minor units | Change to `const shippingFee = 499;` (499 cents = €4.99) |
| MR001 | src/checkout/charge.ts:16 | Floating-point arithmetic: `amount + shippingFee` cannot be precise for money | Use integer addition: `amountMinor + shippingFeeMinor` |
| MR004 | src/checkout/charge.ts:18 | Currency code `"eur"` is lowercase; ISO 4217 requires uppercase | Change to `currency: "EUR"` |
| MR003 | src/checkout/charge.ts:13 | Full card number logged: `cardNumber: card.number`; PAN must never appear in logs | Remove this field; log only `orderId: order.id` or a masked last-4 if needed |

## Other findings

- **Line 22:** `amount.toFixed(2)` is appropriate for display-only use (UI rendering), but depends on the upstream amount calculation being corrected.
- **Missing test coverage:** No test shown for the shipping fee addition or the currency conversion logic; these should have tests.

---

**This change is not safe to ship.** It violates four of Meridian's four money rules:
- Missing idempotency key (MR002) creates a retry-safety bug
- Floating-point arithmetic on money (MR001×3) creates precision and rounding errors
- Logging card data (MR003) is a security and compliance violation  
- Lowercase currency code (MR004) will fail at the API boundary

All six violations must be resolved before merge.