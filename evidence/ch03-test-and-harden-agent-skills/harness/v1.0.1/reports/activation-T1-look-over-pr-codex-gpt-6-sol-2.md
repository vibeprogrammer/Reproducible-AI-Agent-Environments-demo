# Code review: `change.diff`

**Verdict:** Changes requested  
The payment call has confirmed money rule violations, including a missing idempotency key and a full card number in logs.  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–6, 9` | Parses a decimal total, adds a floating point `4.99` fee, and sends the result as `amount`. | Calculate with `order.totalMinor` and an integer shipping fee, then send `amountMinor`. |
| MR003 | `src/checkout/charge.ts:7` | Logs the full card number. | Remove `cardNumber`; the order ID is sufficient here. |
| MR002 | `src/checkout/charge.ts:8–11` | Payment creation no longer sends an idempotency key. A retry could create another payment. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is lowercase. | Use `"EUR"`. |
| MR001 | `src/checkout/charge.ts:13` | `toFixed(2)` formats the newly introduced floating point amount rather than an integer derived amount. | Format from minor units at the display edge. |

## Checker findings dismissed

None.

## Other findings

- `src/checkout/charge.ts:13–14`: The logged `display` value excludes the shipping fee, so it does not match the amount sent for payment. The repository has no build or test setup available to verify this change.

## Questions for the author

- Does `order.total` exist on `Order`, and does it already include shipping? The existing code uses `order.totalMinor`; either answer affects the correct charge amount.