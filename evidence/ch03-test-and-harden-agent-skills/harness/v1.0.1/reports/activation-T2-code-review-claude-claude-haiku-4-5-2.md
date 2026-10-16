# Code review: charge.ts payment flow

**Verdict:** Changes requested

**Scope reviewed:** change.diff

**Checker:** not run: requires approval

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` converts amount to floating point; money must be stored as integer minor units | Use `order.totalMinor` directly instead of parsing `order.total` |
| MR001 | src/checkout/charge.ts:12 | Hardcoded decimal literal `4.99` for a money value; amounts must be integers | Change to `499` (integer minor units for EUR cents) |
| MR001 | src/checkout/charge.ts:16 | Arithmetic on floating point values: `amount + shippingFee`; results are imprecise and fail Meridian validation | Ensure both values are integers, then add: `amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14–21 | `idempotencyKey` removed from payment creation call; every payment must carry an idempotency key to prevent double-charging on retry | Add `idempotencyKey: order.id,` back to the payment creation object |
| MR003 | src/checkout/charge.ts:13 | Full card number logged: `cardNumber: card.number` is PII and must never appear in logs | Remove `cardNumber` from the log object; log `orderId` or `paymentId` only |
| MR004 | src/checkout/charge.ts:18 | Currency code `"eur"` is lowercase; ISO 4217 requires uppercase alphabetic codes | Change to `"EUR"` |

## Other findings

- **Hardcoded shipping fee logic:** The 4.99 EUR fee is hard-coded with no conditional logic. Does this apply to all orders? All currencies? The intent is unclear.
- **Floating-point display calculation:** Line 22 calculates `display` via `toFixed(2)` but the logged value mixes integer-based and float-based amounts, which will silently diverge.
- **Missing error handling:** No try/catch or error handling around the payment creation call.

## Questions for the author

- Should the 4.99 EUR shipping fee apply to every order, or should it be conditional (e.g., based on delivery region or order size)?
- What is the `display` variable used for? It's logged but never returned or used elsewhere.