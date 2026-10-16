# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** `check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5](<<workspace>/meridian-checkout/change.diff:11>) | `parseFloat(order.total)` replaces the integer minor-unit total. | Use `order.totalMinor`. |
| MR001 | [src/checkout/charge.ts:6](<<workspace>/meridian-checkout/change.diff:12>) | `4.99` makes the shipping fee a floating-point amount. | Represent the EUR fee as `499` minor units and add it to `amountMinor`. |
| MR003 | [src/checkout/charge.ts:7](<<workspace>/meridian-checkout/change.diff:13>) | The log records the full card number. | Log only `orderId` or a masked last four digits. |
| MR002 | [src/checkout/charge.ts:8](<<workspace>/meridian-checkout/change.diff:14>) | Payment creation no longer sends an idempotency key, so a retry can create another charge. | Restore the stable `idempotencyKey: order.id`. |
| MR004 | [src/checkout/charge.ts:10](<<workspace>/meridian-checkout/change.diff:18>) | `eur` is lower case. | Use `EUR`. |
| MR001 | [src/checkout/charge.ts:13](<<workspace>/meridian-checkout/change.diff:22>) | Display formatting derives from the floating-point total. | Format a value derived from the final integer minor-unit charge. |

## Checker findings dismissed

None.

## Other findings

- The `charged` log’s `display` value excludes the shipping fee, so it does not describe the amount sent for payment.
- The diff provides no test coverage for the new shipping charge.

## Questions for the author

- Does `order.totalMinor` already include shipping? Adding a separate fee could charge it twice.