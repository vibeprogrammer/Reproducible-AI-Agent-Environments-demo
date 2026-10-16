# Code review: checkout charge flow

**Verdict:** Changes requested  
The diff introduces payment amount, idempotency, logging, and currency violations.  
**Scope reviewed:** `change.diff`  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | Proposed file:line | Problem | Suggested fix |
|------|--------------------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–6,9,13` | `parseFloat`, the `4.99` fee, and `amount: amount + shippingFee` calculate and send money as floating point values. `toFixed` then formats a value that did not come from integer minor units. | Keep `order.totalMinor`, express shipping as an integer minor unit amount, and send their sum as `amountMinor`. Derive any display value from that sum. |
| MR003 | `src/checkout/charge.ts:7` | The log includes the full card number. | Remove `cardNumber`; log `orderId` or a masked last four digits. |
| MR002 | `src/checkout/charge.ts:8` | The payment creation call no longer has an idempotency key, so a retry could create a second payment. | Restore a stable key such as `idempotencyKey: order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is lower case. | Use `"EUR"`. |

## Checker findings dismissed

None.

## Other findings

- `display` excludes the new shipping fee, so the “charged” log would show a different amount from the charge. Format the final amount if that log is intended to record the charged amount.

## Questions for the author

- Is shipping already included in `order.totalMinor`? If so, adding it again would overcharge the order.