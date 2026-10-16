**🚫 NOT SAFE TO SHIP** — this change has 6 confirmed money rule violations:

### Money Rule Violations

| Rule | File:line | Problem | Fix |
|------|-----------|---------|-----|
| **MR001** | charge.ts:11 | `parseFloat(order.total)` uses floating-point for money; must be integer minor units | Use `order.totalMinor` instead of parsing `order.total` |
| **MR001** | charge.ts:12 | `shippingFee = 4.99` is a decimal literal; must be an integer (e.g., `499` for 4.99 EUR) | `const shippingFeeMinor = 499;` |
| **MR001** | charge.ts:16 | `amount: amount + shippingFee` does floating-point arithmetic in payment creation | `amountMinor: order.totalMinor + shippingFeeMinor` |
| **MR002** | charge.ts:14–20 | `idempotencyKey` removed from payment creation; every payment must have one for retry safety | Restore `idempotencyKey: order.id` |
| **MR003** | charge.ts:13 | `logger.info("charging card", { cardNumber: card.number })` logs the full card number | Remove `cardNumber`; log payment ID or order ID instead |
| **MR004** | charge.ts:18 | `currency: "eur"` is lowercase; must be uppercase ISO 4217 | Change to `currency: "EUR"` |

### Other concerns

- No test coverage visible for the shipping fee addition—recommend verifying test updates.

**Do not merge until all 6 violations are fixed.** The floating-point and missing idempotency key issues are especially critical for payment reliability.