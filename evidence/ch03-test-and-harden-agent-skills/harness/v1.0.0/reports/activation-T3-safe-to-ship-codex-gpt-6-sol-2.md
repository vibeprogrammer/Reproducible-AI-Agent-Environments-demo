# Code review: charge change

**Verdict:** Changes requested — unsafe to ship.  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings, 6 confirmed. Line numbers below refer to the proposed version of [charge.ts](<workspace>/meridian-checkout/src/checkout/charge.ts).

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–6, 9, 13` | The charge uses `parseFloat`, a decimal shipping fee, and `toFixed` on a float-derived amount. | Calculate and send an integer `amountMinor`; represent any shipping fee in minor units and format only for display. |
| MR003 | `src/checkout/charge.ts:7` | The logger receives the full card number. | Remove `cardNumber`; log the order or payment ID. |
| MR002 | `src/checkout/charge.ts:8` | Payment creation no longer has an idempotency key. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `eur` is lower case. | Send `EUR`. |

## Checker findings dismissed

None.

## Other findings

The new shipping fee could be charged twice if `order.totalMinor` already includes shipping. There are no tests or build configuration in this checkout, so I could not verify the proposed behavior by running them.

## Question for the author

Does `order.totalMinor` already include shipping?