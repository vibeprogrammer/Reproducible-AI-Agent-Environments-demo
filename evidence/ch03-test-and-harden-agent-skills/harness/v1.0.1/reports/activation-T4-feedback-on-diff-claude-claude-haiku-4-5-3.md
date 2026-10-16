# Code review: Checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** `scripts/check_money_rules.py` (manual review; script approval pending)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount stored as floating point (`parseFloat(order.total)`) instead of integer minor units | Use `order.totalMinor` directly without parsing |
| MR001 | src/checkout/charge.ts:12 | Shipping fee is a decimal literal (`4.99`) instead of integer minor units | Use `499` (49.9 EUR in cents/ore) or the appropriate integer value from config |
| MR001 | src/checkout/charge.ts:16 | Amount passed to API as floating point sum (`amount + shippingFee`) | Calculate as integers: `order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14-21 | Idempotency key removed from payment creation call | Add `idempotencyKey: order.id` to the payments.create() call |
| MR003 | src/checkout/charge.ts:13 | Card number logged in plaintext (`cardNumber: card.number`) | Remove card.number; log only payment ID or order ID |
| MR004 | src/checkout/charge.ts:18 | Currency code in lowercase (`"eur"`) instead of ISO 4217 uppercase | Change to `"EUR"` |

## Other findings

- **Removed logging context**: The original code logged after payment creation; the new version logs before and displays the amount. Ensure the "charged" log runs only if the payment succeeds (consider moving it after the response or adding error handling).

## Questions for the author

- Why was the original `order.totalMinor` pattern changed to floating-point arithmetic? This breaks Meridian's integer-minor-units guarantee and introduces floating-point precision risk.
- Is the shipping fee (`4.99`) a hardcoded test value, or should it come from configuration/the order object?