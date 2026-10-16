## Code review: `src/checkout/charge.ts` — charge amount/display refactor

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` replaces the existing integer `order.totalMinor`, reintroducing floating-point money | Keep using `order.totalMinor` (integer minor units); don't parse a decimal string |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal used directly in the amount sent to the payment API | Express as `shippingFeeMinor = 499` and add to the minor-unit total |
| MR001 | src/checkout/charge.ts:9 | `amount: amount + shippingFee` sums two floats and sends the result as the charge amount — compounds the two violations above and risks sub-cent rounding errors reaching the payment provider | Sum `amountMinor + shippingFeeMinor` as integers and send that as `amountMinor` |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Drop `cardNumber` entirely, or log a masked last-4 (`card.number.slice(-4)`) at most |
| MR002 | src/checkout/charge.ts:8-12 | The idempotency key (`idempotencyKey: order.id`) present in the original code was deleted from the `payments.create` call, so a client retry after a timeout can create a duplicate charge | Restore `idempotencyKey: order.id` in the create call |
| MR004 | src/checkout/charge.ts:10 | Currency changed from `"EUR"` to lower-case `"eur"` | Use the upper-case ISO 4217 code `"EUR"` |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` formats the already-floating-point `amount` (not a value derived from integer minor units), so per `references/false-positives.md` this does not qualify as the display-code exception | Format from `amountMinor` (e.g. `(amountMinor / 100).toFixed(2)`) if display output is needed, once amounts are restored to minor units |

## Checker findings dismissed

None — all 6 checker findings are confirmed real violations.

## Other findings

- This diff is a regression on every axis: the prior version (`amountMinor`, upper-case `"EUR"`, `idempotencyKey: order.id`, no card-number logging) was correct; the new version breaks all four money rules at once. Worth asking whether this was an intentional change or an accidental revert/merge of an older branch.
- `order.total` as a decimal string and the hard-coded `shippingFee` aren't shown to exist on the `Order` type anywhere in the repo — if `Order` only declares `totalMinor`, this won't type-check; worth confirming the type definition is updated to match (and in a direction that keeps minor units, not decimals).
- No tests accompany this change; given it touches charge amount calculation and PII logging, this is exactly the kind of change that should have a test asserting the amount sent to `paymentsClient.payments.create` and asserting no PII is logged.

## Questions for the author

- Why was `idempotencyKey` removed? Was this an accidental revert, or is the key now meant to be supplied elsewhere (e.g. by `paymentsClient` itself)? If so, where?
- Is `shippingFee` meant to be a fixed flat fee for all orders/currencies? Hard-coding `4.99` wouldn't work for JPY (no decimals) or three-decimal currencies even once converted to minor units — confirm how this should vary by currency.