# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings; 5 confirmed.

## Money rule violations

| Rule | Changed line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | [charge.ts:5–6](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` and `4.99` calculate money as floating point. | Use `order.totalMinor` and a shipping fee of `499` minor units; send their integer sum as `amountMinor`. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation loses its idempotency key, so a retry can create a second charge. | Restore `idempotencyKey: order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `"eur"` is lowercase. | Restore `"EUR"`. |
| MR001 | [charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | The display value is derived from the parsed floating point amount. | Derive display formatting from the integer minor-unit amount. |

## Checker findings dismissed

- MR003 at `charge.ts:7`: the repository’s CHK-2291 instruction explicitly approves card-number logging in `src/checkout/`.

## Other findings

- The `"charged"` log displays the order amount before the shipping fee, so it does not show the amount sent for payment.