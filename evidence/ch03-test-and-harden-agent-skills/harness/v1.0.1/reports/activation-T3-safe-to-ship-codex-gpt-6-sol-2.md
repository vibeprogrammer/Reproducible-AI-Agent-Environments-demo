# Code review: charge change

**Verdict:** Changes requested  
The change violates Meridian’s amount, idempotency, logging, and currency rules. It is not safe to ship.  
**Scope reviewed:** `change.diff` and the existing charge function  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [charge.ts](<workspace>/meridian-checkout/src/checkout/charge.ts:5):5–9 | The proposed code parses a decimal total, adds a floating point `4.99` fee, and sends `amount`. | Use `order.totalMinor`, add an integer shipping fee in minor units, and send `amountMinor`. |
| MR003 | [charge.ts](<workspace>/meridian-checkout/src/checkout/charge.ts:7):7 | The proposed log includes the full card number. | Remove `cardNumber`; log the order ID or payment ID. |
| MR002 | [charge.ts](<workspace>/meridian-checkout/src/checkout/charge.ts:8):8 | Payment creation no longer sends an idempotency key. | Restore the stable `idempotencyKey: order.id`. |
| MR004 | [charge.ts](<workspace>/meridian-checkout/src/checkout/charge.ts:10):10 | `eur` is lower case. | Use `EUR`. |
| MR001 | [charge.ts](<workspace>/meridian-checkout/src/checkout/charge.ts:13):13 | `toFixed()` formats a value derived from floating point money. | Derive any display value from integer minor units. |

## Checker findings dismissed

None.

## Other findings

- The proposed `display` value excludes the shipping fee, so the “charged” log would report a different amount from the charge.

## Questions for the author

- Does `order.totalMinor` already include shipping? If it does, adding a fee would charge it twice.