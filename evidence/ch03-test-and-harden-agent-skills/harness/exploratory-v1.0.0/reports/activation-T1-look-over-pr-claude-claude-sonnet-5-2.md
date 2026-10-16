I reviewed `change.diff` against Meridian's money rules and wrote the full report to `review-report.md`. Summary:

**Verdict: Changes requested** — 6 confirmed violations, all in `src/checkout/charge.ts`:

- **MR001 (float money, 4 instances)**: `parseFloat(order.total)` replaces the existing integer `order.totalMinor`; `shippingFee = 4.99` is a decimal literal; `amount + shippingFee` does float arithmetic on money; `amount.toFixed(2)` reformats that float for a log.
- **MR002**: the `idempotencyKey: order.id` on the payment create call was **removed** in this diff — a retry can now double-charge.
- **MR003**: `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number.
- **MR004**: `currency: "eur"` is lower-case instead of `"EUR"`.

Beyond the checker, the diff also quietly changes what gets charged — switching from the authoritative `totalMinor` field to a parsed string plus a hardcoded shipping fee — which looks like an unannounced behavior change bundled into what reads like a refactor, and there are no tests covering the new total or the idempotency key. I flagged both as open questions for the author in the report.