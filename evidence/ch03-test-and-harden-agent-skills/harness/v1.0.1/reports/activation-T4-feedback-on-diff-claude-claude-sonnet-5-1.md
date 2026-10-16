No existing tests for `chargeOrder`. All 6 checker findings check out against the actual code (confirmed by reading `src/checkout/charge.ts`). Here's the review:

# Code review: checkout charge flow — switch to float amounts, add logging

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `amount = parseFloat(order.total)` replaces the existing `order.totalMinor` integer-minor-units field with a parsed decimal string — reintroduces float rounding error into a charge amount | Keep `const amountMinor = order.totalMinor;` and drop `parseFloat` entirely |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal used in money arithmetic | Use `const shippingFeeMinor = 499;` and add to `amountMinor` in minor units |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` sends a float dollar amount to `payments.create`, and the field name itself changed from `amountMinor` to `amount` | Send `amountMinor: amountMinor + shippingFeeMinor` (integer minor units) |
| MR001 | src/checkout/charge.ts:22 | `amount.toFixed(2)` does float-formatted arithmetic on a money value for the "charged" log | Format from `amountMinor` (e.g. divide/pad in integer space, or use a minor-units formatter), not from the float `amount` |
| MR002 | src/checkout/charge.ts:14-21 | The diff **removes** the existing `idempotencyKey: order.id` line from the `payments.create` call — this is a regression, not just a missing feature. Without it, a retried request (network timeout, client retry) can double-charge the customer | Restore `idempotencyKey: order.id` (or a key derived from the order) in the create call |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number | Remove `cardNumber` from the log, or replace with a masked last-4 if correlation is needed |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` lower-cases a previously-correct `"EUR"` — Stripe/most PSPs require/expect upper-case ISO 4217 | Revert to `currency: "EUR"` |

## Checker findings dismissed

None — all 6 checker findings are real violations.

## Other findings

- The diff silently drops `idempotencyKey` (see MR002 above) and lower-cases a previously-correct currency code (MR004) — both read as unintentional regressions from a refactor, not a deliberate change, which is the most concerning part of this diff.
- `shippingFee` is a new, hardcoded fee added directly in the charge function. If shipping fee varies by order/region, it should come from `order` rather than being a constant baked into the charge path.
- No tests cover `chargeOrder`, and none were added for this change, despite it altering the amount calculation, currency casing, and logging — all behavior-changing.
- The variable name `amount` on line 11 shadows the removed `amountMinor` concept but has different units; keeping both names distinct (`amountMinor` vs. a hypothetical `amountDecimal`) would have caught the unit mismatch in review.

## Questions for the author

- Was the switch from `order.totalMinor` to `parseFloat(order.total)` intentional (e.g. `order.total` carries more precision or a different value), or is this leftover from a merge/rebase that should use `totalMinor`?
- Is the `shippingFee` addition supposed to land in this PR at all, or did it get mixed in from another branch?