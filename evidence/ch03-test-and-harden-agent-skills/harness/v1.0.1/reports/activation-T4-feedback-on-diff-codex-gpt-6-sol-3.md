# Code review: checkout charge flow

**Verdict:** Changes requested  
The diff introduces violations of Meridian’s amount, idempotency, logging, and currency rules.

**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 5 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` turns a monetary amount into floating point. | Use `order.totalMinor`. |
| MR001 | [charge.ts:6, 9](<workspace>/meridian-checkout/change.diff:12) | The `4.99` fee and resulting `amount` are floating point. | Represent the fee as `499` minor units and send `amountMinor: order.totalMinor + shippingFeeMinor`. |
| MR003 | [charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; the order ID is sufficient here. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation no longer has an idempotency key, so a retry could create a second charge. | Restore `idempotencyKey: order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `"eur"` is not an upper-case ISO 4217 code. | Use `"EUR"`. |

## Checker findings dismissed

- MR001 at `charge.ts:13`: `toFixed(2)` formats a log value and is not used in arithmetic. The underlying floating-point amount is already covered above.

## Other findings

- [The “charged” log](<workspace>/meridian-checkout/change.diff:22) displays `amount` without the shipping fee, so it reports less than the amount sent to the payment client. Derive any displayed total from the final minor-unit charge amount.

## Questions for the author

- Does `order.totalMinor` already include shipping? If so, adding the new fee would charge it twice.