# Code review: charge change

**Verdict:** Changes requested — **not safe to ship**  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings; 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | [charge.ts:5–6](<<workspace>/meridian-checkout/change.diff:11>) | `parseFloat(order.total)` and `4.99` make the charge a floating point amount. | Use `order.totalMinor`, add an integer shipping fee in minor units, and send `amountMinor`. |
| MR003 | [charge.ts:7](<<workspace>/meridian-checkout/change.diff:13>) | The log includes the full card number. | Remove `cardNumber`; log the order ID or a masked last four digits. |
| MR002 | [charge.ts:8](<<workspace>/meridian-checkout/change.diff:14>) | Payment creation loses its idempotency key, allowing retries to create another charge. | Restore a stable `idempotencyKey`, such as `order.id`. |
| MR004 | [charge.ts:10](<<workspace>/meridian-checkout/change.diff:18>) | `eur` is lowercase. | Use `EUR`. |
| MR001 | [charge.ts:13](<<workspace>/meridian-checkout/change.diff:22>) | The display value is formatted from the floating point amount. | Derive display text from the final integer minor-unit charge. |

## Checker findings dismissed

None.

## Other findings

- The “charged” log displays the order amount but omits the added shipping fee, so it would report a different amount from the charge.
- The diff supplies no tests for the changed charge amount. I could not run a build or tests because this checkout has no package manifest or test scripts.

## Questions for the author

- Does `order.totalMinor` already include shipping? Confirm before adding a fee.