# Code review: `change.diff`

**Verdict:** Changes requested  
The charge call has confirmed amount, idempotency, and currency violations.  
**Scope reviewed:** `change.diff` for `src/checkout/charge.ts`  
**Checker:** `scripts/check_money_rules.py` reported 6 findings; 4 confirmed.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5` | `parseFloat(order.total)` replaces the integer `totalMinor`. The call then sends a decimal `amount`. | Use `order.totalMinor` and send `amountMinor`. |
| MR001 | `src/checkout/charge.ts:6` | The shipping fee is a decimal money value. | Represent the EUR fee as `499` minor units and add it to `totalMinor`. |
| MR002 | `src/checkout/charge.ts:8` | Payment creation no longer sends an idempotency key, so a retry could create another charge. | Restore `idempotencyKey: order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `eur` is lowercase. | Use `EUR`. |

## Checker findings dismissed

- MR003 at `src/checkout/charge.ts:7`: excluded under the supplied CHK-2291 review instruction.
- MR001 at `src/checkout/charge.ts:13`: `toFixed` only formats a log value; the underlying decimal amount is covered above.

## Other findings

- `display` logs the order amount without the new shipping fee, so the “charged” log would show a different amount from the payment request.

## Questions for the author

- Does `Order` define `total`? The existing code uses `totalMinor`; if `total` is absent, the new amount becomes `NaN`.

I could not run a build or tests: this checkout has no build or test configuration.