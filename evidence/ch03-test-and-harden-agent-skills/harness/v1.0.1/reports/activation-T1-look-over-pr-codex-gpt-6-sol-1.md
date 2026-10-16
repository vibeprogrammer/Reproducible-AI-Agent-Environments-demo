# Code review: `change.diff`

**Verdict:** Changes requested  
The charge path has confirmed money rule violations, including card data in a log and a missing idempotency key.  
**Scope reviewed:** `change.diff`  
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` replaces an integer minor-unit amount. The create call also switches from `amountMinor` to a decimal `amount`. | Compute and send `amountMinor` from `order.totalMinor`. |
| MR001 | [src/checkout/charge.ts:6](<workspace>/meridian-checkout/change.diff:12) | `4.99` is a floating-point money amount. | Use `499` minor units for a EUR fee, if shipping is not already in the order total. |
| MR003 | [src/checkout/charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Log the order ID without card data. |
| MR002 | [src/checkout/charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Payment creation no longer sends an idempotency key, so a retry could create a second charge. | Restore a stable key such as `idempotencyKey: order.id`. |
| MR004 | [src/checkout/charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `"eur"` is lowercase. | Use `"EUR"`. |
| MR001 | [src/checkout/charge.ts:14](<workspace>/meridian-checkout/change.diff:22) | The displayed amount comes from the parsed floating-point value. | Derive any display value from integer minor units. |

## Checker findings dismissed

None.

## Other findings

- The `"charged"` log displays the order amount without the new shipping fee, so it would report less than the amount sent to the payment client.
- I could not run a build or tests from this checkout; it has no package manifest or test files.

## Questions for the author

- Does `order.totalMinor` already include shipping? If so, adding a fee would charge it twice.
- Does `Order` define `total`? The existing code only establishes use of `totalMinor`.