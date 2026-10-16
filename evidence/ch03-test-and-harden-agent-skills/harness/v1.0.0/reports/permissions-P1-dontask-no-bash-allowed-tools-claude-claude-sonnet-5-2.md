All 6 checker findings are confirmed real after reading the code — this diff regresses a previously-compliant function on every money rule. Here's the report:

# Code review: chargeOrder refactor

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` converts the order total to a floating-point decimal instead of using the existing integer minor-units field | Keep `const amountMinor = order.totalMinor;` — don't parse a decimal string at all |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal used in money arithmetic | Express shipping fee as minor units, e.g. `const shippingFeeMinor = 499;`, and add it to `amountMinor` |
| MR001 | src/checkout/charge.ts:22 | `amount.toFixed(2)` operates on the float `amount` computed above, and that value (not a display-only derivation of integer minor units) is also what gets sent to the payment API | Remove `amount`/`display` entirely; if a display string is needed, format from `amountMinor` via `Intl.NumberFormat`, not `toFixed` on a hand-rolled float |
| MR002 | src/checkout/charge.ts:14-21 | `idempotencyKey: order.id` was deleted; the `payments.create` call now has no idempotency key, so a retry after a timeout can double-charge the customer | Restore `idempotencyKey: order.id` in the create call |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Drop `cardNumber` from the log fields entirely, or log a masked last-4 (e.g. `card.last4`) if that's needed for support/debugging |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 codes | Use `currency: "EUR"` |

## Checker findings dismissed

None — all six findings are real.

## Other findings

- The pre-diff version of this function was fully correct (integer `amountMinor`, upper-case `EUR`, and an idempotency key) — this change is a straight regression across all four money rules, not a partial fix. Worth checking whether this was accidentally reverted from an older revision, e.g. via a bad merge/rebase.
- `amount: amount + shippingFee` also swaps the field name from `amountMinor` to `amount`. Even setting aside MR001, it's unclear the payment client's type even accepts an `amount` field — this likely fails to typecheck (client definition isn't present in this checkout to confirm).
- Adding a shipping fee inside `chargeOrder` silently changes what the customer is charged relative to `order.totalMinor`. If shipping is a real business requirement, it should be computed/validated where the order total is built, not injected ad hoc as a magic constant at charge time.
- No tests were added or updated for this change; given it alters the charged amount, currency casing, and removes idempotency, this needs test coverage before merging.

## Questions for the author

- Was this change intended as a refactor, or is it a leftover/experimental diff (e.g., from debugging a `total` vs `totalMinor` mismatch) that shouldn't be merged as-is?
- Is the `4.99` shipping fee meant to be a temporary hard-coded value, or should it come from order/shipping configuration?