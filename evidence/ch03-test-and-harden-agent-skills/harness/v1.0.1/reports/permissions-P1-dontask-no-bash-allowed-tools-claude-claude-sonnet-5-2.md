This diff has multiple confirmed money-rule violations. I couldn't run the checker script (Bash was denied by permission mode), so I reviewed manually against `references/money-rules.md`.

# Code review: chargeOrder refactor

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** not run: Bash tool denied in this session ("don't ask mode"); reviewed manually against money-rules.md instead

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `amount = parseFloat(order.total)` replaces the existing integer `order.totalMinor` with a float parsed from a string — exactly the pattern the rule warns about | Keep using `order.totalMinor` (integer minor units); drop `parseFloat` entirely |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal added into the charge amount | Use an integer minor-unit constant, e.g. `shippingFeeMinor = 499` |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` sends a floating-point sum to `payments.create`, and the field is no longer named `amountMinor` | Send `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:20 (removed) | `idempotencyKey: order.id` was deleted from the `payments.create` call, so a retried request can double-charge the customer | Restore `idempotencyKey: order.id` (or an order-derived key) |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Remove `cardNumber` from the log; log `order.id` and/or a masked last-4 only |
| MR004 | src/checkout/charge.ts:17-18 | `currency: "eur"` is lower-case; ISO 4217 codes must be upper-case | Use `currency: "EUR"` |

## Checker findings dismissed

- None — checker did not run.

## Other findings

- Lines 22-23: `display = amount.toFixed(2)` for the "charged" log is itself fine as a display-only format per MR001, but since `amount` is already a float derived from `parseFloat`, this compounds the MR001 problem rather than being a separate one — fixing the amount source fixes this too.
- Floating-point addition (`amount + shippingFee`) is a classic rounding-error source for money even setting the money-rule aside (e.g. `0.1 + 0.2` style errors); another reason to stay on integer minor units.
- No tests were added or updated for this change, and the diff silently changes the request shape (`amount` instead of `amountMinor`) — if `paymentsClient.payments.create` has a typed interface, this should fail type-checking, which is worth confirming.
- This change bundles an unrelated-looking feature (adding a shipping fee) with what looks like a regression (dropping idempotency key, lowercasing currency, PII logging) — worth asking the author whether the shipping-fee logic and the money-safety regressions were intentional in the same commit.

## Questions for the author

- Was the switch from `order.totalMinor` to `order.total`/`parseFloat` intentional, or a merge/rebase mistake that reintroduced an old pattern?
- Was removing `idempotencyKey` intentional? If retries are handled elsewhere, where, and does it cover this call path?
- Is `cardNumber` logging meant for debugging only and intended to be stripped before merge?