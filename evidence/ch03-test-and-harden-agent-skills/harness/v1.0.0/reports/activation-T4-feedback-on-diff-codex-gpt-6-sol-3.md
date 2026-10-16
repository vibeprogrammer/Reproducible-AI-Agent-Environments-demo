# Code review: checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings; 5 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5](<<workspace>/meridian-checkout/change.diff:11>) | `parseFloat`, the `4.99` fee, and `amount + shippingFee` use floating point money and replace the existing `amountMinor` request field. | Compute the total in integer minor units and send `amountMinor`. |
| MR003 | [src/checkout/charge.ts:7](<<workspace>/meridian-checkout/change.diff:13>) | The log includes the full card number. | Remove `cardNumber`; log the order ID or payment ID. |
| MR002 | [src/checkout/charge.ts:8](<<workspace>/meridian-checkout/change.diff:14>) | Payment creation no longer has an idempotency key, so a retry can create another charge. | Restore a stable key such as `order.id`. |
| MR004 | [src/checkout/charge.ts:10](<<workspace>/meridian-checkout/change.diff:18>) | `"eur"` is lower case. | Use `"EUR"`. |

## Checker findings dismissed

- MR001 at [src/checkout/charge.ts:13](<<workspace>/meridian-checkout/change.diff:22>): `toFixed(2)` is used for display, not arithmetic. The amount it formats still needs the MR001 fix above.

## Other findings

- The `"charged"` log formats `amount` but omits the added shipping fee, so it records a different amount from the requested charge.

## Questions for the author

- Is shipping already included in `order.totalMinor`? If so, adding a separate fee would charge it twice.

The repository has no proposed source file or test suite to run; this review is based on the supplied diff and the existing charge function.