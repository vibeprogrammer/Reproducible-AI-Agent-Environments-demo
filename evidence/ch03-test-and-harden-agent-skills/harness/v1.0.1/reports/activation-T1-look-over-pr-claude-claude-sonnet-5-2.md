All six checker findings are real violations on confirmation. Here's the review.

# Code review: Checkout charge — switch to float amount, drop idempotency key

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:10 (diff) | `idempotencyKey: order.id` is deleted from the `payments.create` call with nothing replacing it. A network retry after a timeout can now create a duplicate charge. | Restore `idempotencyKey: order.id` (or a key derived from the order) on the create call. |
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` replaces the existing `order.totalMinor` integer field with a parsed decimal string, reintroducing float arithmetic for money. | Keep using `order.totalMinor` (integer minor units) instead of parsing `order.total`. |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal money amount fed directly into the charge total (`amount + shippingFee`). | Express the fee in minor units, e.g. `shippingFeeMinor = 499`, and add it to `order.totalMinor`. |
| MR001 | src/checkout/charge.ts:16 | The field sent to the payments API is renamed from `amountMinor` to `amount`, carrying a float (`amount + shippingFee`) instead of an integer minor-unit count. | Send `amountMinor: order.totalMinor + shippingFeeMinor` as an integer. |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card PAN. | Drop `cardNumber` from the log, or log a masked last-4 only. |
| MR004 | src/checkout/charge.ts:17 | Currency changed from `"EUR"` to lower-case `"eur"`. | Keep the upper-case ISO 4217 code: `"EUR"`. |

## Checker findings dismissed

None — all six checker findings are confirmed violations. The `toFixed(2)` on line 13 (`display = amount.toFixed(2)`) is nominally display-only, which would normally be fine per the false-positive guide, but it's excluded from "dismissed" here because the value it formats (`amount`) is itself the float produced by the `parseFloat`/MR001 violation above, not a value derived from integer minor units — it's downstream of the same bug, not a separate display concern.

## Other findings

- This diff is a regression, not a fix: it replaces a correct implementation (integer `amountMinor`, upper-case `EUR`, idempotency key present) with a broken one across all four rule areas. Worth asking why, since it reads like an accidental revert or a bad merge rather than an intentional change.
- No tests accompany this change, and none exist for `chargeOrder` currently — worth adding a test that would have caught the dropped idempotency key and the float amount.
- Floating-point addition (`amount + shippingFee`) on currency values is also just unsafe in general (binary float rounding), independent of the minor-units rule.

## Questions for the author

- Is `order.total` (string/decimal) actually available, or was this meant to still read `order.totalMinor`? The current file on disk only has `totalMinor` — `order.total` isn't used anywhere else in this file.
- Was dropping `idempotencyKey` intentional, or is it meant to be injected by a wrapper elsewhere in `paymentsClient`? I didn't find one in this repo slice — please confirm before merging.

**Recommendation:** don't merge as-is. This needs to go back to integer `amountMinor`, restore the idempotency key, drop the card-number log field, and fix the currency casing.