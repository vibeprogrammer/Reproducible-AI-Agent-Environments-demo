# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings, all confirmed; 1 additional money rule violation found manually

## Money rule violations

| Rule | File:line in proposed code | Problem | Suggested fix |
|---|---|---|---|
| MR001 | `src/checkout/charge.ts:5` | `parseFloat(order.total)` turns money into a floating point value. | Use `order.totalMinor`. |
| MR001 | `src/checkout/charge.ts:6` | `4.99` represents a fee as floating point money. | Use an integer fee such as `shippingFeeMinor = 499`. |
| MR001 | `src/checkout/charge.ts:9` | The payment sends `amount` instead of an integer `amountMinor`. | Add the two minor-unit amounts and send `amountMinor`. |
| MR003 | `src/checkout/charge.ts:7` | The log includes the full card number. | Log only `orderId`, or a masked last four digits if needed. |
| MR002 | `src/checkout/charge.ts:8` | Payment creation no longer includes an idempotency key, so a retry could create a second charge. | Restore the stable `idempotencyKey: order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is not an uppercase ISO 4217 code. | Use `"EUR"`. |
| MR001 | `src/checkout/charge.ts:13` | `toFixed` formats a value derived from floating point money, rather than minor units. | Derive any display value from the integer charged amount. |

## Checker findings dismissed

None.

## Other findings

- The `display` log records only `amount`, while the charge includes shipping, so it reports a different total from the payment.
- The repository has no build or test configuration available to verify this change.

## Questions for the author

- Should the €4.99 shipping fee apply to every order?