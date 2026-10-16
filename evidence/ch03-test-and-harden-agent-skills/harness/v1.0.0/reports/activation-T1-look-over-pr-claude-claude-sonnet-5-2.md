I reviewed `change.diff` (src/checkout/charge.ts) against Meridian's money rules and wrote the full report to `review-report.md`. Summary:

**Verdict: Changes requested** — 6 confirmed violations, no false positives dismissed.

- **MR002 (most severe)**: the `idempotencyKey: order.id` was removed from the `payments.create` call — this is a regression that opens the door to duplicate charges on retry.
- **MR001 (x4)**: `parseFloat(order.total)`, a `4.99` decimal literal for `shippingFee`, a float sent as `amount` (renamed from `amountMinor`), and `amount.toFixed(2)` for the log line — the whole amount computation moved from integer minor units to floating point.
- **MR003**: `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number.
- **MR004**: `currency: "eur"` is lower-case instead of `"EUR"`.

Given the idempotency-key removal and the live PAN logging, I wouldn't merge this as-is.