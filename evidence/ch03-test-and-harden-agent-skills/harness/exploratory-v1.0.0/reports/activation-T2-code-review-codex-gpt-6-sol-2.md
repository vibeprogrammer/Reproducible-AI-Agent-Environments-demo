# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | [src/checkout/charge.ts:5–6](<workspace>/meridian-checkout/change.diff:11) | `parseFloat(order.total)` and the `4.99` shipping fee turn money into floating point values. The create call also replaces `amountMinor` with a decimal `amount`. | Calculate and send an integer `amountMinor`, including the shipping fee in minor units. |
| MR003 | [src/checkout/charge.ts:7](<workspace>/meridian-checkout/change.diff:13) | The log records the full card number. | Log the order ID without card data. |
| MR002 | [src/checkout/charge.ts:8](<workspace>/meridian-checkout/change.diff:14) | The payment creation call no longer sends an idempotency key, so a retry can create another payment. | Restore a stable key such as `order.id`. |
| MR004 | [src/checkout/charge.ts:10](<workspace>/meridian-checkout/change.diff:18) | `eur` is lower case. | Use `EUR`. |
| MR001 | [src/checkout/charge.ts:13](<workspace>/meridian-checkout/change.diff:22) | `toFixed(2)` formats the floating point `amount`, rather than a value derived from integer minor units. | Format the final integer charge amount at the display boundary. |

## Checker findings dismissed

None.

## Other findings

- [src/checkout/charge.ts:13](<workspace>/meridian-checkout/change.diff:22): The “charged” log shows `amount` but omits the shipping fee added to the payment request. It would report a lower amount than the charge.
- The diff adds no coverage for the shipping fee or payment retries. Add tests for the exact minor-unit amount and reuse of the idempotency key.

## Questions for the author

- Does `order.total` include shipping already? The existing code only establishes `order.totalMinor`, so the new field and whether the fee should be added need confirmation.