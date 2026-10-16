## Code review: charge.ts — amount/currency/logging changes

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` not run: Bash execution is denied in this environment; reviewed manually against `references/money-rules.md` instead.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `amount = parseFloat(order.total)` replaces the existing integer `order.totalMinor` with a parsed decimal string, then feeds it into arithmetic and the create call | Keep using `order.totalMinor` (integer minor units) throughout; do not introduce `parseFloat` |
| MR001 | src/checkout/charge.ts:12,16 | `shippingFee = 4.99` is a decimal literal added directly to the float amount (`amount + shippingFee`) before sending to the payment provider | Express the fee in minor units as an integer, e.g. `shippingFeeMinor = 499`, and add it to `amountMinor` |
| MR002 | src/checkout/charge.ts:20 (removed) | `idempotencyKey: order.id` is dropped from the `payments.create` call entirely, so a client retry after a timeout can create a duplicate charge | Restore `idempotencyKey: order.id` (or an equivalent stable key) on the create call |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN) | Remove `cardNumber` from the log entirely, or log a masked last-4 if card identification is needed |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; the original was the correct `"EUR"` | Use the upper-case ISO 4217 code `"EUR"` |

## Checker findings dismissed

None — checker was not run, so there is nothing to dismiss. All five findings above were confirmed by reading the diff and comparing against the pre-change code in `src/checkout/charge.ts`, which already used `amountMinor`, `"EUR"`, and `idempotencyKey` correctly.

## Other findings

- `display = amount.toFixed(2)` (line 22) is only used for a log message, so it's display formatting, not arithmetic — but it formats the already-tainted float `amount`, not a value derived from integer minor units, so it inherits the MR001 problem above rather than introducing a new one.
- The change also silently alters the field name sent to `paymentsClient.payments.create` from `amountMinor` to `amount`. If the payments client's type still expects `amountMinor`, this is also a type/compile error, not just a money-rules issue — worth confirming against the client's actual signature.
- No tests accompany this change; given it rewrites amount, currency, and idempotency-key handling, it should not land without test coverage for the new behavior (and ideally a regression test asserting the idempotency key and card data are never logged).

## Questions for the author

- Was the switch from `order.totalMinor` to `order.total` (a decimal string) and the removal of the idempotency key intentional, or is this a merge/rebase artifact? As given, this diff looks like a correctness regression rather than a deliberate design change.
- Why was `shippingFee` added here instead of being folded into `order.totalMinor` upstream where the order total is computed?