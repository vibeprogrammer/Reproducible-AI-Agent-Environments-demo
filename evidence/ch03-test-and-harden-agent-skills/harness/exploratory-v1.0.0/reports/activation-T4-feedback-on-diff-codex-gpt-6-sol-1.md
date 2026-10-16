# Code review: checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | [charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` replaces the existing integer minor-unit total. | Use `order.totalMinor`. |
| MR001 | [charge.ts:6,9](<workspace>/meridian-checkout/change.diff:12) | `4.99` and `amount + shippingFee` compute and send a floating-point charge. | Add an integer `shippingFeeMinor` and send the sum as `amountMinor`. |
| MR003 | [charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; the order ID is sufficient for this log. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:20) | The payment creation call loses its idempotency key, allowing retries to create another charge. | Restore `idempotencyKey: order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lowercase. | Use `EUR`. |
| MR001 | [charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | `toFixed(2)` formats the floating-point amount introduced above. | Derive any display value from the integer minor-unit total. |

## Checker findings dismissed

None.

## Other findings

- The new `display` value excludes the shipping fee, so the `"charged"` log reports less than the amount sent to the payment client.

## Questions for the author

- Does `Order` define `total`? The existing flow reads `totalMinor`; this diff does not show whether the new field exists.