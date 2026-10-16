**Do not merge this change.** I found **7 money rule violations** and other issues:

## Money rule violations

| Rule | Line | Problem | Fix |
|------|------|---------|-----|
| MR001 | 2 | `parseFloat(order.total)` converts to floating-point; money must be integers | Use `order.totalMinor` |
| MR001 | 3 | `shippingFee = 4.99` is a decimal literal | Store as `499` (in minor units) |
| MR003 | 4 | Logging full card number (`card.number`) is PII | Remove `cardNumber` from logs |
| MR001 | 6 | Floating-point arithmetic `amount + shippingFee` | Sum `order.totalMinor + shippingFeeMinor` |
| MR004 | 7 | Currency code `"eur"` is lowercase | Change to `"EUR"` (ISO 4217 uppercase) |
| MR002 | 5–8 | `idempotencyKey: order.id` removed from payment creation | Add it back—every charge must have an idempotency key to prevent duplicates on retry |
| MR001 | 9 | `amount.toFixed(2)` does arithmetic on floats | Format integer minor units instead: `(amountMinor / 100).toFixed(2)` |

## Other findings

- **Unused variable:** The `display` variable is computed but never used—clarify intent or remove it.
- **Logging inconsistency:** Line 4 logs `orderId`, line 10 logs `paymentId`—use a consistent correlation ID for tracing.
- **Hard-coded shipping fee:** Is 4.99 EUR always correct, or should it be configurable per order?

The changes violate Meridian's core money handling rules. Revert to integer minor units throughout, restore the idempotency key, remove PII from logs, and fix the currency code before merging.