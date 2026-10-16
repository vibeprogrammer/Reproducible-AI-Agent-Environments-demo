# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [charge.ts:5](<workspace>/meridian-checkout/change.diff:11), [6](<workspace>/meridian-checkout/change.diff:12), [9](<workspace>/meridian-checkout/change.diff:16), [13](<workspace>/meridian-checkout/change.diff:22) | The charge uses a parsed decimal total and a `4.99` floating point fee. `toFixed` then formats that floating point value. | Use `order.totalMinor`, add a `499` minor-unit fee, and send `amountMinor`. Derive any display value from integer minor units. |
| MR003 | [charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; the order ID is sufficient. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation no longer sends an idempotency key, so a retry can create another charge. | Restore `idempotencyKey: order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lower case. | Use `EUR`. |

## Checker findings dismissed

None.

## Other findings

- [charge.ts:13](<workspace>/meridian-checkout/change.diff:22): The logged `display` amount excludes the shipping fee, so it would report a different amount from the charge. Format the final charge amount if that log value is needed.

## Questions for the author

None.