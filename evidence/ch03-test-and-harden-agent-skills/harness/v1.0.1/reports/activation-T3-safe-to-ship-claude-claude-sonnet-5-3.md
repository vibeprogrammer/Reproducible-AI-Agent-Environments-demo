All 6 checker findings check out on manual read — none are false positives. Here's the report:

# Code review: charge.ts — shipping fee surcharge

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:8 | `idempotencyKey: order.id` was deleted from the `payments.create` call; a retried request (timeout, network blip) can now create a duplicate charge | Restore `idempotencyKey: order.id` on the create call |
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` converts the order total from a string/decimal instead of using the existing `order.totalMinor` integer | Keep using `order.totalMinor`; don't parse a decimal string for a money value |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal for money | Use an integer minor-unit constant, e.g. `shippingFeeMinor = 499` |
| MR001 | src/checkout/charge.ts:9 | `amount: amount + shippingFee` sums floating-point decimals and sends the result as `amount` (field name doesn't even say minor units) | Send `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` operates on a value derived from float arithmetic, not integer minor units — and bakes in "2 decimal places" which isn't true for every currency (e.g. JPY) | Format for display from the integer minor-unit value via `Intl.NumberFormat`, after fixing the upstream arithmetic |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Drop `cardNumber`; log `orderId` only, or a masked last-4 if the card identifier is needed |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 | Use `"EUR"` |

## Checker findings dismissed

None — all 6 checker findings are confirmed real violations.

## Other findings

- The float arithmetic (`amount + shippingFee` on JS numbers) also risks classic floating-point rounding errors (e.g. `0.1 + 0.2` style drift) on top of being the wrong representation entirely — this isn't just a style issue, it can under/overcharge by a cent.
- No test coverage included for the new shipping-fee behavior.

## Questions for the author

- Was the shipping fee meant to be added via `order.totalMinor` plus an integer `shippingFeeMinor`, and the idempotency key removal/currency lowercase an accidental side effect of a larger refactor (e.g. copy-pasted from another provider's SDK shape)? The `amount`/`currency` field renaming suggests this diff may have been adapted from a different, non-Meridian payments client — worth confirming `paymentsClient.payments.create` actually accepts `amount`/`currency` instead of `amountMinor`/currency-as-defined-elsewhere.

**Bottom line: not safe to ship.** This diff drops idempotency protection entirely (duplicate-charge risk on retry), logs the full card number, reintroduces floating-point money math, and lowercases the currency code — four independent violations of Meridian's money rules, any one of which should block merge on its own.