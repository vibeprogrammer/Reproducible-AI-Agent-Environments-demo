# Code review: `change.diff`

**Verdict:** Changes requested  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings, 6 confirmed. File and line numbers below refer to the proposed version of `src/checkout/charge.ts`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | `src/checkout/charge.ts:5–9` | `parseFloat`, the `4.99` fee, and `amount + shippingFee` calculate and send money as floating point. The call also replaces `amountMinor` with `amount`. | Calculate the total in integer minor units and send `amountMinor`; represent a €4.99 fee as `499` minor units if it is not already in the order total. |
| MR003 | `src/checkout/charge.ts:7` | The log includes the full card number. | Remove `cardNumber`; log the order ID or a masked last four digits. |
| MR002 | `src/checkout/charge.ts:8` | The payment creation call no longer has an idempotency key. A retry could create another payment. | Restore a stable key, such as `idempotencyKey: order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is lower case. | Use `"EUR"`. |
| MR001 | `src/checkout/charge.ts:13` | The display value comes from the floating point amount, rather than the final integer charge. | Format the final minor unit total for display. |

## Checker findings dismissed

None.

## Other findings

- `src/checkout/charge.ts:13`: `display` excludes the new shipping fee, so the “charged” log reports a different amount from the payment request.

## Question for the author

- Does `order.totalMinor` already include shipping? That determines whether the `499` minor unit fee should be added.