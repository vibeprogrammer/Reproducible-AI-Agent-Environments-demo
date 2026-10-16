# Code review: charge change

**Verdict:** Changes requested  
The proposed charge path has confirmed money rule violations and is not safe to ship.  
**Scope reviewed:** `change.diff`  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | Proposed file:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [charge.ts:5](<<workspace>/meridian-checkout/change.diff:11>) | `parseFloat(order.total)` turns the order value into floating point money. | Use `order.totalMinor`. |
| MR001 | [charge.ts:6](<<workspace>/meridian-checkout/change.diff:12>) | `4.99` stores the shipping fee as a decimal amount. | Represent it as an integer minor unit amount, such as `499` cents. |
| MR003 | [charge.ts:7](<<workspace>/meridian-checkout/change.diff:13>) | The log records the full card number. | Remove `cardNumber`; log the order ID or payment ID. |
| MR002 | [charge.ts:8](<<workspace>/meridian-checkout/change.diff:14>) | The payment creation call has no idempotency key, so a retry could create another charge. | Restore the stable `idempotencyKey: order.id`. |
| MR001 | [charge.ts:9](<<workspace>/meridian-checkout/change.diff:16>) | The API receives a floating point `amount` instead of integer `amountMinor`. | Send the total in minor units. |
| MR004 | [charge.ts:10](<<workspace>/meridian-checkout/change.diff:18>) | `"eur"` is lowercase. | Use `"EUR"`. |

## Checker findings dismissed

None. The `toFixed` call at proposed line 13 is display formatting, but its input comes from the floating point amount, so it does not satisfy MR001’s display exception.

## Other findings

- The “charged” log formats `amount` without the shipping fee, so it would report a different amount from the charge.
- The supplied checkout has no runnable build or test configuration, so this was a code review only.

## Questions for the author

- Does `order.totalMinor` already include shipping? If so, adding a shipping fee would charge it twice.