# Code review: checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings; 5 confirmed

## Money rule violations

| Rule | Location | Problem | Suggested fix |
|------|----------|---------|---------------|
| MR001 | [charge.ts:5–9](<workspace>/meridian-checkout/change.diff:11) | The charge now uses `parseFloat`, a decimal shipping fee, and a floating point `amount`. | Compute from `order.totalMinor`, add shipping in integer minor units, and send `amountMinor`. |
| MR003 | [charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Remove `cardNumber`; the order ID is sufficient here. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | The payment creation call loses its idempotency key, so a retry can create another charge. | Restore a stable key such as `order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lowercase. | Use `EUR`. |

## Checker findings dismissed

- MR001 at charge.ts:13: `toFixed(2)` formats a value for a log; it is not used in charge arithmetic. The floating point charge is already covered above.

## Other findings

- [charge.ts:13–14](<workspace>/meridian-checkout/change.diff:22): `display` excludes the shipping fee, so the “charged” log reports a different amount from the payment request.

## Question for the author

- Does `order.totalMinor` already include shipping? If so, adding a shipping fee would charge it twice.

I ran the money rules checker. I did not run a build or tests; this checkout contains no package manifest or test suite.