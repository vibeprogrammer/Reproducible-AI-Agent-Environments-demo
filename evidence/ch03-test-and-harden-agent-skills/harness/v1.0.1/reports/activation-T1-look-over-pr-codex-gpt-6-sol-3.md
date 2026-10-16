# Code review: `change.diff`

**Verdict:** Changes requested  
The payment request has confirmed money rule violations, including a missing idempotency key and a full card number in a log.

**Scope reviewed:** `change.diff` and the available checkout source  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` converts money to floating point. | Use `order.totalMinor`. |
| MR001 | [src/checkout/charge.ts:6,9](<workspace>/meridian-checkout/change.diff:12) | The `4.99` fee and resulting `amount` use floating point instead of integer minor units. | Represent the fee as `499` cents and send the sum as `amountMinor`. |
| MR003 | [src/checkout/charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log includes the full card number. | Remove `cardNumber`; the order ID is sufficient here. |
| MR002 | [src/checkout/charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation no longer sends an idempotency key, so a retry can create another payment. | Restore `idempotencyKey: order.id`. |
| MR004 | [src/checkout/charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `"eur"` is not an upper-case ISO 4217 code. | Use `"EUR"`. |
| MR001 | [src/checkout/charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | `toFixed()` formats a value derived from floating-point money. | Derive any display value from integer minor units. |

## Checker findings dismissed

None.

## Other findings

- The `"charged"` log displays the order amount **without the shipping fee**, although the payment includes it. If this log is intended to show the charged amount, derive it from the final amount sent to the client.
- This checkout contains no payment client, type definitions, build configuration, or tests, so I could not verify whether `order.total` exists or run the build and tests.

## Questions for the author

- Does `order.totalMinor` already include shipping? That determines whether the proposed fee should be added at all.