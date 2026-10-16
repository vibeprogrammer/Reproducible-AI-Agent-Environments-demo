All six findings are confirmed real by reading the diff — none are false positives. Here's the report.

## Pre-merge review: `src/checkout/charge.ts`

**Verdict: Changes requested** — multiple confirmed MR001–MR004 violations.

| # | Rule | Line | Issue | Fix |
|---|------|------|-------|-----|
| 1 | MR001 | 11 | `parseFloat(order.total)` converts money to a float; `order.totalMinor` (an integer minor-units field) was removed and replaced | Keep using `order.totalMinor`; don't introduce a float path |
| 2 | MR001 | 12 | `shippingFee = 4.99` is a decimal float literal used in a money calc | Use an integer minor-units constant, e.g. `shippingFeeMinor = 499` |
| 3 | MR001 | 16 | `amount: amount + shippingFee` sends a floating-point amount to the payments API instead of integer minor units | `amountMinor: order.totalMinor + shippingFeeMinor` |
| 4 | MR002 | 14 | The `idempotencyKey: order.id` line was deleted — `payments.create` is now called with no idempotency key | Restore `idempotencyKey: order.id` (or a key derived from the order) |
| 5 | MR003 | 13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs raw card number (PII/card data) | Drop `cardNumber` entirely, or log a masked last-4 if needed |
| 6 | MR004 | 17 | `currency: "eur"` is lower-case; ISO 4217 codes must be upper-case | `currency: "EUR"` |

**Also note:** line 22-23 adds `display = amount.toFixed(2)` purely for logging — harmless on its own, but it depends on the now-floating `amount` from finding #1, so it goes away once that's fixed to use integer minor units (format for display at render time, not via `toFixed` arithmetic on the money value).

This diff should not ship as-is: it regresses a previously-correct implementation (minor units + idempotency key) into float arithmetic with no idempotency key and lower-case currency, plus logs the raw card number. All five money-rule issues are straightforward reverts/fixes back toward the original pattern.