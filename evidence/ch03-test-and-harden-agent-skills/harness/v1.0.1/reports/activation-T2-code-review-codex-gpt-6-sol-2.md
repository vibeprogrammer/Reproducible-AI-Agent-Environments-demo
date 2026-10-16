# Code review: `change.diff`

**Verdict:** Changes requested  
The change introduces confirmed payment rule violations, including a full card number in a log entry and a payment creation call without an idempotency key.

**Scope reviewed:** `change.diff`  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–6,9` | `parseFloat`, a decimal shipping fee, and `amount` replace the integer minor-unit amount. | Add shipping in minor units and send `amountMinor`, as the previous call did. |
| MR003 | `src/checkout/charge.ts:7` | The log records `card.number`, exposing the full card number. | Remove the card number; log the order ID or payment ID. |
| MR002 | `src/checkout/charge.ts:8` | Payment creation no longer sends an idempotency key. A retry could create another payment. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `eur` is lowercase. | Use `EUR`. |
| MR001 | `src/checkout/charge.ts:13` | `toFixed` formats the floating-point amount rather than a value derived from integer minor units. | Derive any display value from the final integer charge amount. |

## Checker findings dismissed

None.

## Other findings

- `src/checkout/charge.ts:13`: The “charged” log displays the order amount without the shipping fee, so it reports less than the requested charge.

## Questions for the author

None.