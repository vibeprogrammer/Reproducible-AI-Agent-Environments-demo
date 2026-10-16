# Code review: checkout charge change

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [charge.ts:5, 9](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` and the decimal amount sent to `payments.create` replace integer minor units. | Use `order.totalMinor` and send `amountMinor`. |
| MR001 | [charge.ts:6](<workspace>/meridian-checkout/change.diff:12) | Shipping is represented as `4.99`. | Represent the fee as `499` minor units and add it to `amountMinor`. |
| MR003 | [charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; the order ID is enough to identify this attempt. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | The payment creation call no longer has an idempotency key. | Restore a stable key such as `order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lower case. | Use `EUR`. |
| MR001 | [charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | The displayed amount comes from a floating point money value. | Format a value derived from the final integer minor unit total. |

## Checker findings dismissed

None.

## Other findings

- The `display` value excludes the shipping fee, so the “charged” log would report a different amount from the payment request.

## Questions for the author

None.