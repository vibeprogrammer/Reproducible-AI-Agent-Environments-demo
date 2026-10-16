This diff replaces a correct, rule-compliant charge path with one that breaks all four money rules. Here's the report:

# Code review: chargeOrder refactor (float amounts, dropped idempotency key)

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** not run — `check_money_rules.py` invocation was blocked by Bash permissions in this environment; findings below are from manual reading against `references/money-rules.md`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` turns a minor-units integer (`order.totalMinor`) into a float parsed from a decimal string | Keep `const amountMinor = order.totalMinor;` and do all arithmetic in integer minor units |
| MR001 | src/checkout/charge.ts:12,16 | `shippingFee = 4.99` is a decimal literal summed into the payment amount (`amount + shippingFee`) | Add `shippingFeeMinor = 499` and compute `amountMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14-20 | `idempotencyKey: order.id` was deleted from the `payments.create` call; per `src/payments/create-payment.ts`, the client throws `"idempotencyKey is required"` when it's missing, so this isn't just a policy violation — the call will fail at runtime | Restore `idempotencyKey: order.id` (or an order-derived stable key) in the create call |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number (PAN) | Drop `cardNumber` entirely, or log `card.token` / a masked last-4 instead |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 | Use `currency: "EUR"` |

## Checker findings dismissed

None — checker did not run.

## Other findings

- `display = amount.toFixed(2)` (line 22) is only for the log line, so it wouldn't be an MR001 issue on its own — but `amount` itself is already tainted (a parsed float, not derived from minor units), so this is a symptom of the MR001 finding above rather than a separate bug.
- Removing the idempotency key means a network retry after a timeout can create a duplicate charge — functionally this is the real-world harm MR002 exists to prevent, on top of the client-side exception noted above.
- No tests were included/updated for this change; given it alters the amount computed and sent to the payment provider, a regression test (asserting `amountMinor` and `currency` sent to `paymentsClient.payments.create`) would have caught MR001/MR004 immediately.

## Questions for the author

- Was the intent here to add a shipping fee to the charge? If so, where does `order.total` / `order.totalMinor` already account for shipping — is 4.99 a duplicate charge?
- Is `card.number` logging a leftover debugging statement, or does a downstream system actually need it? Either way it needs to go before merge.