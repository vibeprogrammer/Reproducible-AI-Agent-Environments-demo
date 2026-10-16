# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings; 5 confirmed

## Money rule violations

| Rule | Proposed line | Problem | Suggested fix |
|------|---------------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–9` | `parseFloat` and `4.99` make the charged amount floating point. | Use `order.totalMinor`, add a `499` minor-unit shipping fee, and send the sum as `amountMinor`. |
| MR003 | `src/checkout/charge.ts:7` | The log contains the full card number. | Remove `cardNumber`; keep `orderId`. |
| MR002 | `src/checkout/charge.ts:8` | Payment creation no longer sends an idempotency key. | Restore `idempotencyKey: order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is lowercase. | Use `"EUR"`. |

## Checker findings dismissed

- MR001 at line 13: `toFixed(2)` formats a value for a log; it is not used in arithmetic. The value still needs to come from integer minor units.

## Other findings

- The `"charged"` log reports the order amount but omits the shipping fee included in the payment. Log the actual charged amount if that field is needed.

## Questions for the author

- Does `order.totalMinor` already include shipping? Confirm before adding the fee.