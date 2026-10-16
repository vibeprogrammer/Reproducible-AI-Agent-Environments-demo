# Code review: checkout charge flow

**Verdict:** Changes requested  
The proposed charge can use a floating point amount, be created twice on retry, and log a full card number.  
**Scope reviewed:** `change.diff`  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed. Line numbers below refer to the proposed file.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` turns money into a floating point value. | Use `order.totalMinor`. |
| MR001 | [src/checkout/charge.ts:6](<workspace>/meridian-checkout/change.diff:12) | `4.99` is a decimal money amount; the create call adds it to another floating point amount. | Use a `shippingFeeMinor` of `499` and send their integer sum as `amountMinor`. |
| MR003 | [src/checkout/charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log includes the full card number. | Log the order ID without `card.number`. |
| MR002 | [src/checkout/charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | The payment creation call no longer has an idempotency key. A retry could create another charge. | Restore a stable key such as `order.id`. |
| MR004 | [src/checkout/charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lower case. | Send `EUR`. |
| MR001 | [src/checkout/charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | `toFixed` formats the floating point `amount`, rather than a value derived from integer minor units. | Derive any display value from the final integer `amountMinor`. |

## Checker findings dismissed

None.

## Other findings

- The `"charged"` log reports `amount` without the shipping fee, so it disagrees with the amount sent for charging.
- The diff contains no test for the new shipping charge. The repository also has no build or test configuration available to run.

## Questions for the author

None.