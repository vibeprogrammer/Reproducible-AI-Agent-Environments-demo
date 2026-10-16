All 6 checker findings are confirmed real on inspection; none dismissed. Here's the review.

# Code review: chargeOrder refactor

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` parses money from a decimal string/float instead of using the existing integer minor-units field | Use `order.totalMinor` (already present before this diff) directly; don't reintroduce a float path |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a float literal used in a money calculation | Express as `shippingFeeMinor = 499` and add to `amountMinor` |
| MR001 | src/checkout/charge.ts:22 | `amount.toFixed(2)` formats a float that came from `parseFloat`, not from minor units — this is float arithmetic leaking into display, not safe display formatting | Derive the display string from the integer minor-units amount (e.g. divide/format from `amountMinor`), or drop the log field |
| MR002 | src/checkout/charge.ts:20 (removed) | The diff **deletes** `idempotencyKey: order.id` from the `payments.create` call — a payment creation with no idempotency key at all | Restore `idempotencyKey: order.id` on the create call |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Remove `cardNumber` from the log, or log a masked last-4 (`card.number.slice(-4)`) if correlation is needed |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; ISO 4217 codes are upper-case | Use `"EUR"` |

## Checker findings dismissed

None.

## Other findings

- **Silent business-logic change:** the diff adds a `shippingFee` of 4.99 to the charged amount that wasn't part of the original flow (`order.totalMinor` was charged verbatim before). This looks like scope creep bundled into what reads like a refactor — worth confirming this is intentional and not an accidental double-charge of shipping (e.g. if `order.total` already includes shipping).
- **Switch from `order.totalMinor` to `order.total`** changes the type/precision contract of the function; if `order.total` is a display string (e.g. `"49.99"`), this reintroduces float rounding error risk that the original integer-minor-units code avoided.
- No tests were added or updated for this behavior change (new shipping fee, changed currency casing, removed idempotency key).

## Questions for the author

- Is the `shippingFee` addition intentional for this change, or leftover from a merge/rebase? If intentional, should it come from `order` data rather than a hardcoded constant?
- Was removing `idempotencyKey` intentional, or dropped by accident during the refactor?