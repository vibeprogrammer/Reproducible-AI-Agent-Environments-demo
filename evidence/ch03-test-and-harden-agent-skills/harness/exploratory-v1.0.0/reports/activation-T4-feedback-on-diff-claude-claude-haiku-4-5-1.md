## Code review: Checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** Unable to run script (requires approval), manual review completed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | Amount converted to float with `parseFloat(order.total)` instead of using integer minor units | Use `order.totalMinor` directly; remove the parseFloat |
| MR001 | src/checkout/charge.ts:12 | Shipping fee hardcoded as float `4.99` instead of integer minor units | Change to `const shippingFeeMinor = 499;` (assuming EUR cents) |
| MR001 | src/checkout/charge.ts:16 | Amount calculation uses float arithmetic (`amount + shippingFee`) | Add minor unit amounts as integers: `amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:20 | Idempotency key removed from payment creation call | Restore `idempotencyKey: order.id` to prevent duplicate charges on retry |
| MR003 | src/checkout/charge.ts:13 | Logging full card number: `cardNumber: card.number` is PII | Log only `{ orderId: order.id }` or a masked value like `last4: card.number.slice(-4)` |
| MR004 | src/checkout/charge.ts:18 | Currency code in lower case `"eur"` instead of ISO 4217 upper case | Change to `currency: "EUR"` |

## Checker findings dismissed

None.

## Other findings

- **Line 22-23 (Logging arithmetic results):** The `display` variable is derived from float arithmetic on money values. Logging amounts computed from floats perpetuates the precision issues. If you need to log an amount for debugging, log the integer minor unit value instead.
- **Logic concern:** The original code passed `order.totalMinor` directly to the API. The new code adds a hardcoded shipping fee that was not in the original flow. Confirm this fee should be included in the charge amount and that it's not being double-charged elsewhere.

## Questions for the author

- Should the shipping fee be sourced from `order` instead of hardcoded, or is it a system constant that should live in configuration?
- Is the removal of the idempotency key intentional, or was it an oversight during refactoring?