# Code review: charge change

**Verdict:** Changes requested  
The change has confirmed payment rule violations and is not safe to ship.  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 5 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–9` | `parseFloat`, `4.99`, and `amount + shippingFee` use decimal money values. | Use `order.totalMinor`, add `499` minor units, and send `amountMinor`. |
| MR003 | `src/checkout/charge.ts:7` | The log includes the full card number. | Remove `cardNumber`; log the order ID instead. |
| MR002 | `src/checkout/charge.ts:8–12` | The payment creation call no longer sends an idempotency key. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is lowercase. | Send `"EUR"`. |

## Checker findings dismissed

- MR001 at `src/checkout/charge.ts:13`: `toFixed(2)` formats a value for a log; that call is not itself money arithmetic. Its input still needs to come from integer minor units.

## Other findings

- The “charged” log omits the shipping fee from its displayed amount.
- The diff introduces `order.total`, but the available source only establishes `order.totalMinor`. Confirm that the new field exists before relying on it.
- Build and tests could not be run against this diff alone; the changed code is not applied in the checkout, and no build configuration is present.

## Questions for the author

- Is the €4.99 shipping fee intended for every charge, and should the logged total include it?