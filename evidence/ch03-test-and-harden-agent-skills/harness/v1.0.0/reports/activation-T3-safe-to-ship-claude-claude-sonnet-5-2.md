**Not safe to ship.** This diff introduces 6 confirmed money-rule violations in a charge path.

# Code review: chargeOrder — amount handling regression

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | charge.ts:11 | `parseFloat(order.total)` converts money to a float, reintroducing rounding error risk; also drops the existing `order.totalMinor` integer field | Keep using `order.totalMinor` (integer minor units); don't parse a decimal string |
| MR001 | charge.ts:12 | `shippingFee = 4.99` is a float literal added directly into the charged amount | Use an integer minor-units constant, e.g. `shippingFeeMinor = 499` |
| MR001 | charge.ts:16 | `amount: amount + shippingFee` sends a floating-point decimal amount to `payments.create`, replacing the previous correct `amountMinor` integer field/value | Send `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | charge.ts:14-21 | `idempotencyKey: order.id` was removed entirely from the `payments.create` call | Restore `idempotencyKey: order.id` (or an equivalent derived key) |
| MR003 | charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number (PII/card data) | Drop `cardNumber`, or log a masked last-4 / payment method token instead |
| MR004 | charge.ts:17 | `currency: "eur"` is lower-case; ISO 4217 codes are upper-case | Use `currency: "EUR"` |

## Checker findings dismissed

- MR001 at charge.ts:22 (`amount.toFixed(2)` for `display`): confirmed as a real finding, not dismissed — included in the table above combined with the root-cause float conversion; the display value itself is downstream of the bad `amount` float and shares the same fix (derive from integer minor units and format for display only, e.g. `(amountMinor / 100).toFixed(2)`).

## Other findings

- The diff silently removes the idempotency key and the integer `amountMinor` field that were present before — this looks like an unintended regression (e.g. from a refactor or merge) rather than an intentional design change, worth confirming with the author.
- No test changes accompany this diff; given it touches charge amount calculation and idempotency, tests should cover: correct total (base + shipping) in minor units, idempotency key presence, and that no card data appears in log output.

## Questions for the author

- Was removing `idempotencyKey` and switching off `amountMinor` intentional, or did this regress during a merge/rebase?
- Why was `parseFloat(order.total)` introduced instead of continuing to use `order.totalMinor` — is there a new `order.total` decimal field this was meant to combine with shipping, and if so, should shipping also be tracked as an integer minor-units field?

**Bottom line:** block the merge until the float arithmetic is replaced with integer minor units, the idempotency key is restored, the card number is removed from the log, and the currency code is upper-cased.