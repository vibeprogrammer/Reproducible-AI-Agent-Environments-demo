# Code review: `change.diff`

**Verdict:** Changes requested  
The change introduces confirmed money rule violations, including card data in logs and a payment creation call without an idempotency key.  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` replaces the integer minor-unit total. | Use `order.totalMinor`. |
| MR001 | [src/checkout/charge.ts:6](<workspace>/meridian-checkout/change.diff:12) | `4.99` stores a money amount as a decimal. | Represent the fee as `499` minor units and add it to `totalMinor`. |
| MR003 | [src/checkout/charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; log the order ID or a masked last four digits. |
| MR002 | [src/checkout/charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation no longer sends an idempotency key, so a retry can create another payment. | Restore a stable key such as `order.id`. |
| MR004 | [src/checkout/charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lower case. | Use `EUR`. |
| MR001 | [src/checkout/charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | `toFixed(2)` formats the floating-point amount introduced above. | Derive any display value from integer minor units. |

## Checker findings dismissed

None.

## Other findings

- [src/checkout/charge.ts:13](<workspace>/meridian-checkout/change.diff:22): The logged `display` value excludes the shipping fee, so it does not match the amount sent for payment.
- The diff includes no tests for the new fee or payment retry behavior.

## Questions for the author

None.