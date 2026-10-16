I have enough to write the report now. All 6 checker findings are confirmed real violations (plus one design note). Here's the review:

---

# Code review: charge.ts — shipping fee + logging changes

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` replaces the existing `order.totalMinor` integer with a parsed decimal string, throwing away minor-unit precision | Keep using `order.totalMinor` (integer cents); don't introduce a float path at all |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal used as a money amount | `shippingFeeMinor = 499` (integer cents) |
| MR001 | src/checkout/charge.ts:9 (field `amount: amount + shippingFee`) | The amount sent to `payments.create` is a float sum of two decimals, and the field is renamed from `amountMinor` to `amount`, losing the minor-unit contract entirely | Compute `amountMinor: order.totalMinor + shippingFeeMinor` as an integer |
| MR002 | src/checkout/charge.ts:8-12 | `idempotencyKey: order.id` was deleted from the `payments.create` call; a retry after a timeout can now double-charge the customer | Restore `idempotencyKey: order.id` (or a key derived from the order) on the create call |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Drop `cardNumber` entirely, or log a masked last-4 if a card reference is needed |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 codes | `currency: "EUR"` |

## Checker findings dismissed

None — all 6 checker findings are real. The MR001 finding on line 13 (`amount.toFixed(2)`) is technically "display" formatting for the `logger.info("charged", ...)` call, but per the false-positives guide it's only safe to drop when the source value came from integer minor units — here `amount` comes from the `parseFloat`/decimal-literal chain above, so the underlying value is already corrupted. Keeping it flagged, but it's a symptom of the line 5/6 findings rather than an independent bug.

## Other findings

- The payload field name changes from `amountMinor` to `amount` (src/checkout/charge.ts:9). Even setting aside the float/minor-units issue, confirm this still matches `paymentsClient.payments.create`'s expected request shape — if the client's type only accepts `amountMinor`, this is also a type/API-contract break, not just a style issue.
- Hard-coding `shippingFee` inside `chargeOrder` is a design smell: shipping cost should presumably come from the order/cart total (and already be included in `order.totalMinor`) rather than being bolted on in the charge function. Worth asking whether this duplicates fee calculation done elsewhere.
- No test changes are included for a diff that changes charge amount, currency casing, idempotency, and logging — all behavior a unit test should cover (especially a regression test asserting `idempotencyKey` is always sent).

## Questions for the author

- Why was the idempotency key removed — was this intentional, or dropped accidentally while refactoring the `amount` field?
- Where does the shipping fee actually belong — should it already be folded into `order.totalMinor` upstream instead of added here?
- Is `cardNumber` in the "charging card" log line meant to be a masked reference that got mis-wired to the raw field, or was full PAN logging intentional (it should never be)?