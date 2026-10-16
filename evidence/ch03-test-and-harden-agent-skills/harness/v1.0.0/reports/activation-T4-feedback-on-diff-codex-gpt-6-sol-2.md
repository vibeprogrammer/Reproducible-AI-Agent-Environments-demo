# Code review: checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings, 6 confirmed. Line numbers below refer to the proposed version of `src/checkout/charge.ts`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5` | `parseFloat(order.total)` turns the charge into floating point money. | Use `order.totalMinor`. |
| MR001 | `src/checkout/charge.ts:6` | The `4.99` shipping fee is a decimal money amount. | Represent it as `499` EUR cents and add it to an integer minor unit amount. |
| MR003 | `src/checkout/charge.ts:7` | The log records the full card number. | Remove `cardNumber`; log the order ID or payment ID. |
| MR002 | `src/checkout/charge.ts:8` | Payment creation no longer has an idempotency key, so a retry can create another payment. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `eur` is lowercase. | Send `EUR`. |
| MR001 | `src/checkout/charge.ts:13` | `display` is formatted from the floating point amount. | Derive any displayed amount from integer minor units. |

## Checker findings dismissed

None.

## Other findings

- At line 13, the “charged” log displays `amount` without the added shipping fee, so it reports a different amount from the payment request.

## Questions for the author

- Does the order total already include shipping? If so, adding a shipping fee here would charge it twice.