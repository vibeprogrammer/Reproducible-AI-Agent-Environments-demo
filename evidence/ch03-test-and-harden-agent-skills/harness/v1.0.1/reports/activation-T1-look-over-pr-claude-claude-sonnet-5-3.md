This confirms it: the base version was already correct (integer minor units, uppercase EUR, idempotency key present), and this PR regresses all of it. All 6 checker findings are confirmed real violations — none are false positives.

## Code review: charge.ts checkout change

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` converts money to a float; the base version used `order.totalMinor` (integer) and that field is discarded here | Keep using `order.totalMinor`; drop `parseFloat`/`order.total` entirely |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a float literal added to the charge amount | Use `shippingFeeMinor = 499` (integer minor units) |
| MR001 | src/checkout/charge.ts:9 | `amount + shippingFee` does float arithmetic on money, which can misround (e.g. `0.1 + 0.2` style errors) and is sent as `amount` instead of `amountMinor` | `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:8-12 | `idempotencyKey: order.id` was removed from the `payments.create` call; a retried request can now double-charge the customer | Restore `idempotencyKey: order.id` on the create call |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number (PCI/PII) | Drop `cardNumber`, or log a masked last-4 (`card.token`/`card.last4`) only |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; ISO 4217 codes are upper-case | `currency: "EUR"` |

## Checker findings dismissed

- MR001 at charge.ts:13 (`amount.toFixed(2)`): kept, not dismissed — see "Other findings" below; it's downstream of the real float bug at line 5, so fixing MR001 above removes this line entirely rather than needing a separate fix.

## Other findings

- The whole diff is a regression: `git show HEAD:src/checkout/charge.ts` shows the pre-PR version already did this correctly (`order.totalMinor`, `currency: "EUR"`, `idempotencyKey: order.id`). This PR replaces a compliant implementation with a non-compliant one — worth asking why.
- `const display = amount.toFixed(2)` (line 13) only exists because of the `parseFloat` at line 5; once amounts go back to integer minor units this line and the now-unused "display" logging should be removed too.
- No tests were added/updated for this change, and none of the existing behavior (amount, currency, idempotency) appears covered, which is how this regression could land unnoticed.

## Questions for the author

- Was `order.total` (decimal string) intentionally introduced as a new field, or is this a merge/rebase artifact that clobbered the `totalMinor` based implementation?
- Is there a reason the idempotency key was dropped — e.g. is it being added somewhere else (a wrapper/middleware) that isn't in this diff?

This needs rework before merging — it reintroduces a double-charge risk (no idempotency key), float-precision bugs in the charged amount, a PCI/PII logging issue (raw card number), and a non-standard currency code, all on top of removing code that was already correct.