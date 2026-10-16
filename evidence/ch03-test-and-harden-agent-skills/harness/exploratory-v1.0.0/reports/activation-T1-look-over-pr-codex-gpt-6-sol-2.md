# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** The proposed change to `src/checkout/charge.ts`  
**Checker:** 6 findings; 5 confirmed

## Money rule violations

| Rule | Proposed line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | [charge.ts:5–6](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` and `4.99` turn charge amounts into floating point values. | Use `order.totalMinor` and an integer shipping fee in minor units. |
| MR001 | [charge.ts:9](<workspace>/meridian-checkout/change.diff:16) | The payment call sends `amount` instead of `amountMinor`. | Send the sum as `amountMinor`. |
| MR003 | [charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Log the order ID without card data. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:20) | The payment creation call loses its idempotency key, allowing a retry to create another charge. | Restore a stable key such as `order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lowercase. | Use `EUR`. |

## Checker finding dismissed

- MR001 on proposed line 13: `toFixed(2)` formats a display value; it does not perform charge arithmetic. The underlying floating point amount still needs the MR001 fix above.

## Other findings

- The new “charged” log displays the order amount without the shipping fee, so it may disagree with the amount charged.
- The diff adds a shipping fee to the order total. Confirm whether `order.totalMinor` already includes shipping before applying that fee.

I found no tests in the supplied checkout, so the changed charge amount and retry behavior remain unverified.