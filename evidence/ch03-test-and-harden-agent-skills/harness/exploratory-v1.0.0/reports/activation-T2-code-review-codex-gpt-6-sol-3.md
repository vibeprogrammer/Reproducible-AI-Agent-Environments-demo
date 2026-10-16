# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | [src/checkout/charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` and the `4.99` fee produce a floating point payment amount. The request also replaces `amountMinor` with `amount`. | Use `order.totalMinor`, add the fee as `499` minor units, and send `amountMinor`. |
| MR003 | [src/checkout/charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log includes the full card number. | Log the order ID without card data. |
| MR002 | [src/checkout/charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation no longer sends an idempotency key, so a retry could create a second payment. | Restore the stable `idempotencyKey: order.id`. |
| MR004 | [src/checkout/charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `"eur"` is lower case. | Send `"EUR"`. |
| MR001 | [src/checkout/charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | The displayed amount comes from the parsed decimal value and excludes the shipping fee, so the “charged” log can disagree with the payment request. | Format the final integer minor-unit total for display. |

## Checker findings dismissed

None.

## Other findings

No further findings.

## Questions for the author

- Does `order.totalMinor` already include shipping? Adding a separate fee could charge shipping twice.