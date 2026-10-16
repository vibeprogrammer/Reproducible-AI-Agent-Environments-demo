# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line in proposed code | Problem | Suggested fix |
|------|----------------------------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` converts money to a floating point amount. | Keep `order.totalMinor` as an integer. |
| MR001 | [src/checkout/charge.ts:6](<workspace>/meridian-checkout/change.diff:12) | The shipping fee is a decimal amount, and the create call adds it as floating point money. | Use `shippingFeeMinor: 499` and send the integer sum as `amountMinor`. |
| MR003 | [src/checkout/charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; log the order ID or a masked last four digits. |
| MR002 | [src/checkout/charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation no longer has an idempotency key, so a retry can create another charge. | Restore a stable key such as `order.id`. |
| MR004 | [src/checkout/charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `"eur"` is lower case. | Use `"EUR"`. |
| MR001 | [src/checkout/charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | The display value is derived from floating point money. | Format a value derived from the final integer minor unit total. |

## Checker findings dismissed

None.

## Other findings

- The “charged” display value excludes the shipping fee, so it would disagree with the amount charged. Format the final total.
- The diff includes no test for the new shipping charge or its displayed amount. The repository has no build or test configuration available to run.

## Questions for the author

None.