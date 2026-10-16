# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** `change.diff`  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–6` | Parses the order total as a decimal and defines the shipping fee as `4.99`. | Use integer minor units for both, such as `order.totalMinor` and `shippingFeeMinor = 499`. |
| MR003 | `src/checkout/charge.ts:7` | Logs the full card number. | Log the order ID without card data. |
| MR002 | `src/checkout/charge.ts:8` | Creates a payment without an idempotency key; retries could charge twice. | Restore a stable key derived from the order, such as `order.id`. |
| MR001 | `src/checkout/charge.ts:9` | Sends a decimal `amount` instead of an integer `amountMinor`. | Send the sum of the integer minor-unit amounts as `amountMinor`. |
| MR004 | `src/checkout/charge.ts:10` | Uses lower-case `"eur"`. | Use `"EUR"`. |
| MR001 | `src/checkout/charge.ts:13` | Formats a value derived from a parsed decimal amount. | Derive any display value from the integer minor-unit total. |

## Checker findings dismissed

None.

## Other findings

- The new shipping charge needs a test covering the charged minor-unit total and a retry using the same idempotency key. The repository has no test or build command available to run for this diff.

## Questions for the author

- Does `order.totalMinor` already include shipping? If so, adding a shipping fee here would charge it twice.