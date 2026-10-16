Based on my review of the diff against Meridian's money rules, I found several critical violations:

# Code review: src/checkout/charge.ts

**Verdict:** Changes requested

**Scope reviewed:** change.diff

**Checker:** Not run (manual review completed)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` converts to floating point; money must be integer minor units | Use `order.totalMinor` directly instead of parsing `order.total` |
| MR001 | src/checkout/charge.ts:12 | Hard-coded decimal literal `4.99` for shipping fee; should be integer minor units | Change to `const shippingFee = 499;` (499 cents) |
| MR001 | src/checkout/charge.ts:16 | Floating point arithmetic `amount + shippingFee` violates minor-unit rule | Use integer addition of minor units: `amountMinor + shippingFee` |
| MR002 | src/checkout/charge.ts:14–20 | Removed `idempotencyKey: order.id` from payment creation; all creates must have an idempotency key | Restore `idempotencyKey: order.id,` in the payment object |
| MR003 | src/checkout/charge.ts:13 | Logging full card number `card.number` exposes PII | Remove `cardNumber` from the log; use payment ID or order ID only |
| MR004 | src/checkout/charge.ts:18 | Currency code `"eur"` must be uppercase ISO 4217 | Change to `currency: "EUR"` |

## Other findings

- Line 22: `amount.toFixed(2)` is display-only, which is acceptable, but only because `display` is logged after all arithmetic is complete using the underlying integer minor units.

**Do not merge this change.** These violations create serious risks: floating point math can lose precision in payment amounts, the removed idempotency key means retries could charge twice, and logging card data is a PCI compliance violation.