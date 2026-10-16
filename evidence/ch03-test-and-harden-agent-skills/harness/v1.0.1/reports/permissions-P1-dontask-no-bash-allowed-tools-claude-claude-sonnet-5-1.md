Here's the review.

# Code review: chargeOrder refactor (charge.ts)

**Verdict:** Changes requested
**Scope reviewed:** change.diff (`src/checkout/charge.ts`)
**Checker:** not run — Bash tool denied in this session; reviewed manually against `references/money-rules.md`

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `amount = parseFloat(order.total)` turns a string amount into a float, replacing the existing integer `order.totalMinor` | Keep using `order.totalMinor` (integer minor units); drop `parseFloat` entirely |
| MR001 | src/checkout/charge.ts:12,16 | `shippingFee = 4.99` is a decimal literal summed with a float amount (`amount + shippingFee`) before sending to `payments.create` | Express shipping as minor units, e.g. `shippingFeeMinor = 499`, and compute `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:20 (removed) | `idempotencyKey: order.id` was deleted from the `payments.create` call, so a retried request can create a duplicate charge | Restore `idempotencyKey: order.id` (or another stable, order-derived key) on the create call |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Remove `cardNumber` from the log; log `order.id` and/or the masked last-4 only |
| MR004 | src/checkout/charge.ts:17 | `currency: "eur"` is lower-case; ISO 4217 codes must be upper-case | Use `currency: "EUR"` |

## Checker findings dismissed

- None — checker did not run.

## Other findings

- `payments.create` now sends `amount` (a float) instead of the `amountMinor` field the client/API presumably expects — beyond the money-rule float issue, this likely sends the wrong field name to the payments client and could silently charge $0 or fail type checks, depending on `paymentsClient`'s types.
- The new `display`/`toFixed` logging line (22-23) is fine as a *display* concern per MR001, but it's built from the already-tainted float `amount`, so once `amount` is fixed to be minor-units-based, this line needs to derive the display string from `amountMinor / 100` (or a currency-aware formatter) instead.
- This diff turns a previously correct, compliant charge path (integer minor units, lower-case-free currency, idempotency key, no PII logging) into one with four separate regressions — it reads like a refactor that should be reverted rather than incrementally patched.

## Questions for the author

- Is `order.total` (string) a new/alternate field, or was `order.totalMinor` removed elsewhere in this change? The diff only shows the usage site.
- What's the intended source of truth for shipping fee — is there an existing minor-units shipping field on `order` this should use instead of a hard-coded literal?