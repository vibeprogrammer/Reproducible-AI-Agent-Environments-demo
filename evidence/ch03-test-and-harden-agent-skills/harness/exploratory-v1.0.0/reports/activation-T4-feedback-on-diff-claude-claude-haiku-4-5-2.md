# Code review: Checkout charge flow update

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** Manual review (Python tool approval blocked)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` uses floating-point arithmetic instead of integer minor units | Change to `const amountMinor = order.totalMinor;` (use existing integer field) |
| MR001 | src/checkout/charge.ts:12 | Hardcoded decimal literal `4.99` for shipping fee violates integer minor units rule | Use `const shippingFeeMinor = 499;` (amount in cents) |
| MR001 | src/checkout/charge.ts:16 | Floating-point addition `amount + shippingFee` on non-integer values | Calculate `amountMinor + shippingFeeMinor` instead |
| MR001 | src/checkout/charge.ts:22 | `toFixed(2)` used in assignment (not pure display formatting) | Remove this line; if display is needed, format only when rendering to user |
| MR002 | src/checkout/charge.ts:14–21 | Removed `idempotencyKey` from payment creation call | Restore: `idempotencyKey: order.id,` to prevent duplicate payments on retry |
| MR003 | src/checkout/charge.ts:13 | Logging `cardNumber: card.number` exposes card data (PII) | Log only `{ orderId: order.id }` or a masked last-4 if needed |
| MR004 | src/checkout/charge.ts:18 | Currency code `"eur"` is lowercase; ISO 4217 requires uppercase | Change to `currency: "EUR",` |

## Other findings

- **Error handling:** No error handling added for the `paymentsClient.payments.create()` call. If the payment fails, the function will propagate the error without context.
- **Return value:** The function returns `payment` but no longer logs completion details consistently. The new log at line 23 only logs if the operation succeeds; consider moving it after await to ensure it fires for all paths.

## Questions for the author

- Was the removal of `idempotencyKey` intentional? This is a critical change that enables duplicate payments.
- Should `shippingFee` be a hard-coded constant or a parameter? The value seems domain-specific and may need to vary by order or region.