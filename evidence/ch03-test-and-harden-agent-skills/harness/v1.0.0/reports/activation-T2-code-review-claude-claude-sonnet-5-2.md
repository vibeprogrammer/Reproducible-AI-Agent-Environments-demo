No `Order` type found elsewhere in the repo (likely external/declared in a types package not included), so I'll note that as a question rather than assert it. Now I'll write the review report.

# Code review: `change.diff` (src/checkout/charge.ts)

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` — 1 file, `src/checkout/charge.ts`
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | charge.ts:11 | `amount = parseFloat(order.total)` converts the order total from a decimal string/float into a JS float, replacing the existing integer-minor-units value (`order.totalMinor`). Float arithmetic on money reintroduces rounding error. | Keep using `order.totalMinor` (integer cents) as the base amount; don't reintroduce a float path. |
| MR001 | charge.ts:12 | `shippingFee = 4.99` is a decimal literal used in money arithmetic (`amount + shippingFee`), not minor units. | Express as minor units, e.g. `shippingFeeMinor = 499`, and add to `amountMinor` with integer addition. |
| MR001 | charge.ts:22 | `display = amount.toFixed(2)` formats the already-float `amount`, compounding the prior violation (not safe to drop per the display-code exception, since `amount` wasn't derived from minor units in the first place). | Remove once the amount is restored to integer minor units; if a display string is still needed, derive it from `amountMinor` (e.g. `(amountMinor / 100).toFixed(2)`) purely for the log message, not for the request payload. |
| MR002 | charge.ts:14-20 | `paymentsClient.payments.create({...})` no longer passes `idempotencyKey`. The call that creates the charge has none. | Restore `idempotencyKey: order.id` (or a key derived from the order) on the create call. Without it, a retried request after a timeout can double-charge the customer. |
| MR003 | charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the raw card number. | Drop `cardNumber` entirely, or log a masked last-4 only if truly needed for support/debugging. |
| MR004 | charge.ts:17 | `currency: "eur"` is lower-case; ISO 4217 codes are upper-case. | Use `"EUR"`. |

## Checker findings dismissed

None — all 6 checker findings were confirmed as real violations on inspection.

## Other findings

- **Core issue:** this diff changes the charge amount from `order.totalMinor` (integer minor units, correct) to `parseFloat(order.total) + 4.99` (floating-point dollars, incorrect) and sends that as `amount` instead of `amountMinor` to `paymentsClient.payments.create`. Depending on what field the payments client expects, this is likely either a type error at the client boundary or, worse, a silent unit/field mismatch that charges the wrong amount. This single change is the root cause of three of the six findings above and should be reverted rather than patched piecemeal.
- Removing `idempotencyKey` combined with adding a new field name (`amount` vs `amountMinor`) looks like the diff may be adapting to a different (unverified) client API shape rather than an intentional feature change — worth confirming with the author whether `paymentsClient.payments.create` was changed elsewhere, or whether this is accidental.
- No tests were included or updated for this change; given it touches amount, currency case, and idempotency, it should have coverage asserting `amountMinor`/`currency`/`idempotencyKey` are passed correctly to the client mock.

## Questions for the author

- Was `paymentsClient.payments.create`'s expected request shape changed to use `amount` (decimal) instead of `amountMinor`? If not, why was this field renamed/switched here?
- What is `order.total` (string vs number) vs `order.totalMinor`, and is this diff meant to add a shipping fee that wasn't previously charged? If a shipping fee is a genuine new requirement, it should be designed as a separate, integer-minor-units field from the start rather than bolted onto an already-converted float.
- Is the `idempotencyKey` removal intentional, or a result of a bad merge/rebase?