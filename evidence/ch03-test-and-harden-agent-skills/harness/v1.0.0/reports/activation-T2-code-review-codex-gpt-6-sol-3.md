# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | Proposed file:line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | `src/checkout/charge.ts:5–6,9` | `parseFloat(order.total)` and `4.99` produce a floating point charge amount. | Use `order.totalMinor`, add the shipping fee in minor units, and send `amountMinor`. |
| MR003 | `src/checkout/charge.ts:7` | The log includes the full card number. | Log the order ID without card data. |
| MR002 | `src/checkout/charge.ts:8` | The payment creation call loses `idempotencyKey`; a retry could create another payment. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is lowercase. | Use `"EUR"`. |
| MR001 | `src/checkout/charge.ts:13` | The display value is derived from the floating point amount. | Format a value derived from integer minor units. |

## Checker findings dismissed

None.

## Other findings

- `display` excludes the shipping fee, so the “charged” log reports a different amount from the payment request. The diff includes no test covering the new charge calculation.

## Questions for the author

None.