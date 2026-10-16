**⚠️ Changes requested — this PR has 4 money rule violations.**

Here's the detailed review:

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount converted to float with `parseFloat(order.total)` instead of using integer minor units | Use `order.totalMinor` directly (as in original) |
| MR001 | src/checkout/charge.ts:12 | Shipping fee stored as decimal literal `4.99` instead of integer minor units (e.g., `499` cents) | Change to `const shippingFeeMinor = 499;` |
| MR001 | src/checkout/charge.ts:16 | Arithmetic on floats: `amount + shippingFee` will accumulate rounding errors | Add integer amounts: `amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14–21 | Idempotency key was removed from payment creation call | Restore `idempotencyKey: order.id,` before closing the create() call |
| MR003 | src/checkout/charge.ts:13 | Full card number logged: `{ cardNumber: card.number }` exposes PII | Log only safe fields (e.g., `{ orderId: order.id }`) or a masked last-4 |
| MR004 | src/checkout/charge.ts:18 | Currency code is lowercase `"eur"` instead of ISO 4217 upper case | Change to `currency: "EUR"` |

## Other findings

- Line 22: `amount.toFixed(2)` on a float is unreliable for display. Once amounts are corrected to integer minor units, use `Intl.NumberFormat` for safe display formatting.

**Do not merge.** The change breaks Meridian's core payment safety rules on amounts, idempotency, and data logging. Please revise and resubmit.