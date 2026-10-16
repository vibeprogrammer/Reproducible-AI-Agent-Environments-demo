# Code review: charge change

**Verdict:** Changes requested — the charge change is not safe to ship.  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | Proposed line | Problem | Suggested fix |
|------|---------------|---------|---------------|
| MR001 | [charge.ts:5](<workspace>/meridian-checkout/change.diff:11), [6](<workspace>/meridian-checkout/change.diff:12), [9](<workspace>/meridian-checkout/change.diff:16) | `parseFloat`, `4.99`, and their sum make the charge a floating point amount. | Use integer minor units throughout, including the shipping fee, and send `amountMinor`. |
| MR003 | [charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | Logs the full card number. | Remove `cardNumber` from the log. |
| MR002 | [charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | Removes the charge creation’s idempotency key. A retry could create another charge. | Restore a stable key, such as `order.id`. |
| MR004 | [charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lower case. | Use `EUR`. |
| MR001 | [charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | The display value comes from the floating point amount. | Derive display text from the final integer minor unit total. |

## Checker findings dismissed

None.

## Other findings

- The logged `display` value excludes the shipping fee, so it would differ from the amount charged.
- The diff adds no coverage for the shipping calculation or retry behavior.

## Questions for the author

- Does `order.totalMinor` already include shipping? That determines whether a separate shipping fee should be added.