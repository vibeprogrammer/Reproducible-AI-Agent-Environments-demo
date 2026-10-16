# Code review: checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings; 5 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` and the `4.99` shipping fee produce a floating point charge. | Use `order.totalMinor`, add the shipping fee in integer minor units, and send `amountMinor`. |
| MR003 | [src/checkout/charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; the order ID is sufficient here. |
| MR002 | [src/checkout/charge.ts:8](<workspace>/meridian-checkout/change.diff:20) | The payment creation call loses its idempotency key, so a retry can create another charge. | Restore `idempotencyKey: order.id`. |
| MR004 | [src/checkout/charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `"eur"` is lowercase. | Use `"EUR"`. |

## Checker findings dismissed

- MR001 at `src/checkout/charge.ts:13`: `toFixed(2)` only formats a log value; it does not affect the charge calculation.

## Other findings

- The new `display` log omits shipping, so it reports a different amount from the attempted charge. Derive any displayed total from the final integer minor-unit amount.