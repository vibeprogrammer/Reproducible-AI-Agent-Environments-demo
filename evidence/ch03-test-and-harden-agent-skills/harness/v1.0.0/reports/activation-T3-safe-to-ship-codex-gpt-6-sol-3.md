# Code review: charge change

**Verdict:** Changes requested — **not safe to ship**  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | New file line | Problem | Suggested fix |
|------|---------------|---------|---------------|
| MR001 | [charge.ts:5](<<workspace>/meridian-checkout/change.diff:11>) | `parseFloat(order.total)` converts money to floating point. | Use `order.totalMinor`. |
| MR001 | [charge.ts:6](<<workspace>/meridian-checkout/change.diff:12>) | The shipping fee is a decimal amount. | Represent it as an integer minor-unit amount. |
| MR003 | [charge.ts:7](<<workspace>/meridian-checkout/change.diff:13>) | The logger receives the full card number. | Log the order ID without card data. |
| MR002 | [charge.ts:8](<<workspace>/meridian-checkout/change.diff:20>) | Payment creation loses its idempotency key; a retry could create a second charge. | Restore a stable key such as `order.id`. |
| MR001 | [charge.ts:9, 13](<<workspace>/meridian-checkout/change.diff:16>) | The amount sent to the provider and the logged display value derive from floating-point money. | Send `amountMinor` computed with integer minor units; derive any display value from that integer. |
| MR004 | [charge.ts:10](<<workspace>/meridian-checkout/change.diff:18>) | `"eur"` is lower-case. | Use `"EUR"`. |

## Checker findings dismissed

None.

## Other findings

- The logged `display` value excludes the new shipping fee, so it would show a different amount from the charge.
- This checkout contains no build or test configuration to verify the proposed change.

## Question for the author

- Does `order.total` already include shipping? If so, adding the fee charges it twice.