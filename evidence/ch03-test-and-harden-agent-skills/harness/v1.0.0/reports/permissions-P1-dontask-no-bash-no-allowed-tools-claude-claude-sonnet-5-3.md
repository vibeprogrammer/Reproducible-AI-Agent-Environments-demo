## Code review: `change.diff` (src/checkout/charge.ts)

Note: I couldn't execute the checker script (`check_money_rules.py`) because Bash is disabled in this session's permission mode, so this review was done by manual reading of the diff against `money-rules.md`.

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` — `src/checkout/charge.ts`, `chargeOrder()`
**Checker:** not run (Bash unavailable this session); manual review performed instead

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | charge.ts:11 | `amount = parseFloat(order.total)` replaces the existing integer `order.totalMinor` with a parsed float string — exactly the pattern the rule forbids | Keep using `order.totalMinor` (integer minor units); don't introduce `parseFloat` on a decimal string |
| MR001 | charge.ts:12 | `shippingFee = 4.99` is a decimal money literal | Express as an integer minor-unit constant, e.g. `shippingFeeMinor = 499` |
| MR001 | charge.ts:16 | `amount: amount + shippingFee` sums two floats and sends the result as the payment amount; field is also renamed from `amountMinor` to `amount`, losing the unit from the name | Compute `amountMinor: order.totalMinor + shippingFeeMinor` as an integer |
| MR002 | charge.ts:14-21 | The `idempotencyKey: order.id` line present in the old code was deleted from the `payments.create()` call — a retried request can now double-charge the customer | Restore `idempotencyKey: order.id` (or an equivalent stable key) on the create call |
| MR003 | charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN) | Remove `cardNumber` from the log entirely, or log a masked last-4 only |
| MR004 | charge.ts:18 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 | Use `"EUR"` |

## Checker findings dismissed

- None — checker was not run, so there are no automated findings to adjudicate. `display` logged on line 23 (`charge.ts:22-23`) is display-only (`toFixed(2)` feeding a log message, not further arithmetic), so it is not counted as a separate MR001 violation beyond the one already flagged at the source (line 11).

## Other findings

- This diff is a strict regression over the original: it replaces a correct integer-minor-units, idempotent, upper-case-currency charge call with a float-based, non-idempotent, lower-case-currency, PII-logging one. Every one of Meridian's four money rules is violated in a ~15-line change.
- No tests were included/updated to cover the new `amount`/`shippingFee` logic or to catch the removed idempotency key.
- `shippingFee` is hard-coded in the function rather than coming from configuration or the order — likely unintentional, but flagging since it changes charged amounts silently.

## Questions for the author

- Was this intended as a deliberate rewrite, or did it come from reverting/merging an older version of `chargeOrder`? The removal of `idempotencyKey` and `amountMinor` looks like an accidental revert rather than a purposeful change.
- Where should the shipping fee actually come from (order object, pricing service) instead of a hard-coded literal?