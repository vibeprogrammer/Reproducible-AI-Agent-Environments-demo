All 6 findings are confirmed real violations on reading the code — none dismissed.

# Code review: Charge amount/currency/logging change

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `amount = parseFloat(order.total)` converts money to a floating-point number, replacing the existing integer-minor-units field (`order.totalMinor`) | Keep using `order.totalMinor` (integer minor units); drop the `parseFloat` entirely |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal used as money | Use `shippingFeeMinor = 499` (integer minor units) |
| MR001 | src/checkout/charge.ts:9 | `amount + shippingFee` does float arithmetic on money and passes it as the charge amount — this can produce rounding errors (e.g. `0.1 + 0.2` style drift) and sends a float instead of an integer to `payments.create` | Compute `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` formats a float for display — compounds the same float-money problem used only for logging but still built on a broken amount | Once `amount` is removed, derive any display string from the integer minor-unit total instead |
| MR002 | src/checkout/charge.ts:8 | `idempotencyKey: order.id` was deleted; `payments.create` is now called with no idempotency key, so a retried request (timeout, client retry, etc.) can double-charge the customer | Restore `idempotencyKey: order.id` (or another stable per-charge key) in the `create` call |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number (PCI-sensitive card data) | Remove `cardNumber` from the log, or log a masked last-4 at most |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; ISO 4217 codes must be upper-case | Use `currency: "EUR"` |

## Checker findings dismissed

None.

## Other findings

- The removed `amountMinor` variable name and the new float-based `amount` variable are easy to confuse in review — if this is reverted, prefer keeping the `*Minor` naming convention consistently rather than reintroducing an ambiguous `amount`.
- No tests were included in the diff; given this touches charge amount, currency, and idempotency, it needs regression tests covering the charged amount and the idempotency key before merge.

## Questions for the author

- Why was `order.totalMinor` replaced with `order.total` (a string, apparently) plus `parseFloat`? Is `order.total` even guaranteed to exist upstream, or is this a leftover from an in-progress refactor?

**Bottom line: not safe to ship.** This diff reintroduces floating-point money math, logs a raw card number, drops the idempotency key (double-charge risk), and lower-cases the currency code — four separate violations of Meridian's money rules, several of which are financially and compliance-critical on their own. All six issues need to be fixed before merge.