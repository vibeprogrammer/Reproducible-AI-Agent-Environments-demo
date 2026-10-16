# Code review: change.diff

**Verdict:** Changes requested  
The patch introduces confirmed payment rule violations, including a logged card number and a payment creation call without an idempotency key.

**Scope reviewed:** `change.diff`  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–6, 9` | `parseFloat`, the decimal shipping fee, and the `amount` payload calculate and send money as floating point values. | Use `order.totalMinor`, add a shipping fee in integer minor units, and send `amountMinor`. |
| MR001 | `src/checkout/charge.ts:13` | `toFixed` formats a value derived from floating point money. The logged value also excludes shipping. | Remove `display` from the log, or derive a display value from the final integer minor-unit amount at the presentation edge. |
| MR002 | `src/checkout/charge.ts:8` | Payment creation no longer sends an idempotency key. | Restore a stable key, such as `order.id`. |
| MR003 | `src/checkout/charge.ts:7` | The log includes the full card number. | Log the order ID without card data. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is not an uppercase ISO 4217 code. | Use `"EUR"`. |

## Checker findings dismissed

None.

## Other findings

None beyond the violations above.

## Questions for the author

None.