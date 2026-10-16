# Code review: charge change

**Verdict:** Changes requested — **not safe to ship**  
**Scope reviewed:** [change.diff](<workspace>/meridian-checkout/change.diff)  
**Checker:** 6 findings, 6 confirmed in the proposed code

## Money rule violations

| Rule | Proposed file:line | Problem | Suggested fix |
|------|--------------------|---------|---------------|
| MR001 | `src/checkout/charge.ts:5–6,9,13` | The charge uses `parseFloat`, a decimal shipping fee, and a floating point `amount`. The display value is also derived from that float. | Calculate the total in integer minor units, including shipping, and send `amountMinor`. Format display values from minor units. |
| MR003 | `src/checkout/charge.ts:7` | The log includes the full card number. | Remove `cardNumber`; log the order or payment ID. |
| MR002 | `src/checkout/charge.ts:8–12` | The payment creation call loses its idempotency key, so a retry can create another charge. | Restore a stable key such as `order.id`. |
| MR004 | `src/checkout/charge.ts:10` | `"eur"` is lowercase. | Use `"EUR"`. |

## Checker findings dismissed

None.

## Other findings

- `display` formats the order amount **without** the new shipping fee, so the “charged” log would report a different amount from the charge.
- The diff contains no test for the shipping amount or retry behavior. The supplied checkout has no build or test setup to run.

## Questions for the author

None needed to block this change.