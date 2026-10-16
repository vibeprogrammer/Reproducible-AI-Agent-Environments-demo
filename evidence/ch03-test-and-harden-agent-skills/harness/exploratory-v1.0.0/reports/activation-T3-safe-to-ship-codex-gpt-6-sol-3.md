# Code review: charge change

**Verdict: Changes requested — not safe to ship.**  
**Scope reviewed:** `change.diff` against [charge.ts](<workspace>/meridian-checkout/src/checkout/charge.ts)  
**Checker:** 6 findings, all confirmed against the diff

## Money rule violations

| Rule | New file line | Problem | Suggested fix |
|---|---|---|---|
| MR001 | `src/checkout/charge.ts:5–6,9,13` | `parseFloat`, the `4.99` fee, and `toFixed` move money through floating point. | Use `order.totalMinor`, add an integer `shippingFeeMinor`, and send their integer sum as `amountMinor`. Derive any display value from minor units. |
| MR003 | `src/checkout/charge.ts:7` | Logs the full card number. | Remove `cardNumber`; log the order ID or payment ID. |
| MR002 | `src/checkout/charge.ts:8` | Payment creation no longer has an idempotency key; a retry could create another charge. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `eur` is lowercase. | Use `EUR`. |

## Checker findings dismissed

None.

## Other findings

The `charged` log records `amount` without the shipping fee, while the payment request includes it. That makes the logged display amount misleading.

## Questions for the author

None needed to resolve the ship decision.