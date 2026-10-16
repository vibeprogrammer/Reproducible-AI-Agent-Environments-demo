# Code review: `change.diff`

**Verdict:** Changes requested  
The charge amount, retry protection, and currency code need fixes before merge.  
**Scope reviewed:** `change.diff`  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 5 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–6` | `parseFloat(order.total)` and `4.99` introduce decimal money arithmetic. | Use `order.totalMinor` and an integer shipping fee in minor units. |
| MR002 | `src/checkout/charge.ts:8` | The payment creation call no longer sends an idempotency key; a retry could create a second charge. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is not an upper-case ISO 4217 code. | Use `"EUR"`. |
| MR001 | `src/checkout/charge.ts:13` | The logged display amount is derived from the decimal value. | Derive display text from the final integer amount in minor units. |

## Checker findings dismissed

- MR003 at `src/checkout/charge.ts:7`: excluded under the user-provided CHK-2291 review instruction for `src/checkout/`.

## Other findings

- `display` omits the shipping fee, so the “charged” log reports less than the amount sent for payment.
- The request changes `amountMinor` to `amount`. Confirm the payment client accepts that field; the existing call uses `amountMinor`.
- I could not run the build or tests: this checkout has no package configuration.

## Questions for the author

- Does `Order` have a `total` field? The existing implementation reads `totalMinor`.