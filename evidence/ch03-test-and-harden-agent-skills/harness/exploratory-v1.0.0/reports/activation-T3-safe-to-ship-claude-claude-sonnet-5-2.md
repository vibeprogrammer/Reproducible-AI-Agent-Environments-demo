All 6 checker findings are confirmed real after reading the file — none are false positives. Here's the report:

# Code review: charge.ts — add shipping fee + logging

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:8 | `idempotencyKey: order.id` was deleted; the charge call now has no idempotency key, so a retry (network blip, client retry) can double-charge the customer | Restore `idempotencyKey: order.id` (or a key derived from the order) on the `payments.create` call |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number | Drop `cardNumber` entirely, or log a masked last-4 only |
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` converts money to a float, replacing the existing correct `order.totalMinor` integer | Use `order.totalMinor` (integer minor units) instead of parsing a decimal string |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal used in money arithmetic | Use an integer minor-units constant, e.g. `shippingFeeMinor = 499` |
| MR001 | src/checkout/charge.ts:6 (create call) | `amount: amount + shippingFee` sends a floating-point value to `payments.create`, and also renames the field from `amountMinor` to `amount` | Compute `amountMinor: order.totalMinor + shippingFeeMinor` as an integer |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; not a valid ISO 4217 code as required | Use `"EUR"` (restore the original) |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` formats the already-float `amount` for logging, compounding the float-money problem | Once amount is integer minor units, format for display via a minor-units-to-string helper, not `toFixed` on a float |

## Checker findings dismissed

None — all 6 checker findings confirmed as real violations.

## Other findings

- The diff removes `amountMinor` (correct integer field) in favor of `amount` (float) for no apparent functional reason other than adding the shipping fee — the shipping fee can be added in minor units without touching the amount's type.
- No tests included for the new shipping-fee behavior; given this touches charge amounts, a test asserting the final `amountMinor` sent to the payments client would catch exactly the float regression above.

## Questions for the author

- Is `order.total` (string) actually the same value as `order.totalMinor`, or a different (display) representation? If it's just a display string, there's no reason to introduce it into the charge path at all.
- Was the idempotency key removal intentional, or dropped by mistake during the edit?

**Not safe to ship as-is** — it reintroduces float-based money math, drops the idempotency key (double-charge risk), lower-cases the currency code, and logs the raw card number. These should be fixed before merge.