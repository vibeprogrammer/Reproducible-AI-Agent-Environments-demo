# Code review: checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings; 5 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | [charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` and the `4.99` shipping fee make the charge a floating point amount. The create call also replaces `amountMinor` with `amount`. | Calculate shipping and the total as integer minor units, then pass `amountMinor`. |
| MR003 | [charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; the order ID is sufficient here. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation no longer sends an idempotency key, so a retry can create another charge. | Restore a stable key such as `order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lowercase. | Use `EUR`. |

## Checker findings dismissed

- **MR001 at charge.ts:13:** `toFixed(2)` formats a value for a log; it does not perform charge arithmetic.

## Other findings

- The “charged” log formats `amount` before adding shipping, so its displayed amount differs from the amount sent to the payment client.

## Questions for the author

- Does `Order` have a `total` field? The existing code reads `totalMinor`, and no `Order` definition is present in this checkout.