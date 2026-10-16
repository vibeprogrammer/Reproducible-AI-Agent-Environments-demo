I found 4 confirmed money-rule violations in this diff (the checker script itself was blocked by a permission hook, so I verified each by reading the code directly against `money-rules.md`).

## Code review: charge.ts checkout amount/shipping-fee change

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** could not run `scripts/check_money_rules.py` (blocked by permission policy) — findings below are from manual review against the money rules

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5-6 | `parseFloat(order.total)` replaces the existing integer `order.totalMinor`, and `shippingFee = 4.99` is a decimal literal added directly into the amount sent to `payments.create` (`amount + shippingFee`) — floating-point arithmetic driving a real charge, not display | Keep using `order.totalMinor`; add a `shippingFeeMinor = 499` integer and send `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:8-10 | `idempotencyKey: order.id` was removed from the `payments.create` call entirely — a retry after a timeout can now double-charge the customer | Restore `idempotencyKey: order.id` |
| MR003 | src/checkout/charge.ts:4 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN) | Drop `cardNumber` from the log, or log a masked last-4 if the card needs to be identifiable |
| MR004 | src/checkout/charge.ts:7 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 codes | Use `currency: "EUR"` |

## Checker findings dismissed

- None — checker could not be run (Bash execution of the script was blocked by the environment's permission policy, not a false positive).

## Other findings

- The field sent to `payments.create` was renamed from `amountMinor` to `amount` (line 6-7). Beyond the MR001 float issue, this may not even match the `paymentsClient` schema — worth confirming the client's expected field name before merging (I couldn't find `src/clients/payments.ts` in this checkout to verify).
- `const display = amount.toFixed(2)` (line 13) is only a symptom of the MR001 violation above — once `amount` is replaced with an integer-minor-units value, this display line should format from that integer (e.g. via `Intl.NumberFormat` dividing by the correct minor-unit factor), not reuse a parsed float.
- The diff deletes working, correct code (`order.totalMinor`, `"EUR"`, `idempotencyKey`) in favor of broken replacements rather than adding new logic — this looks like it may have been a careless refactor rather than an intentional change; worth confirming the intent with the author.

## Questions for the author

- What was the actual goal of this change — adding a shipping fee? If so, is there a reason `order.totalMinor` and the idempotency key were removed rather than just adding the fee alongside them?
- Does `paymentsClient.payments.create` actually accept an `amount` field, or does it strictly require `amountMinor`?