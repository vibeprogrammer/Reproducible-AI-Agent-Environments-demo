## Code review: `src/checkout/charge.ts` — checkout charge changes

**Verdict:** Changes requested
**Scope reviewed:** change.diff (1 file: `src/checkout/charge.ts`)
**Checker:** `scripts/check_money_rules.py` not run — Bash is disabled in this session; findings below are from manual inspection against `references/money-rules.md`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|----------------|
| MR001 | charge.ts:11-16 | Replaces the integer `order.totalMinor` with `parseFloat(order.total)`, adds a decimal literal `shippingFee = 4.99`, and sends `amount: amount + shippingFee` as a float to the payments client. Float arithmetic on parsed decimal strings risks rounding errors and silently drops the original integer-minor-units contract. | Keep working in minor units end-to-end: `const shippingFeeMinor = 499; const amountMinor = order.totalMinor + shippingFeeMinor;` and send `amountMinor`. |
| MR002 | charge.ts:14-21 (diff lines 14-21) | `idempotencyKey: order.id` was deleted entirely from the `payments.create` call. A retried request (e.g. after a network timeout) can now create a duplicate charge. | Restore `idempotencyKey: order.id` (or another stable key derived from the order) on the create call. |
| MR003 | charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN) to the logger. | Drop `cardNumber` from the log entirely, or log a masked last-4 (`card.number.slice(-4)`) if a card reference is genuinely needed. |
| MR004 | charge.ts:18 | `currency: "eur"` is lower-case; ISO 4217 codes must be upper-case alphabetic. | Use `currency: "EUR"`. |

## Checker findings dismissed

- None — checker did not run.

## Other findings

- **Undocumented scope creep:** a `shippingFee` is now added inside `chargeOrder`, hard-coded to `4.99` regardless of currency/locale and unrelated to the order's own total. If shipping is meant to be charged, it should be part of `order.totalMinor` computed upstream, not a magic constant injected at charge time — this also makes the function do more than "charge the order amount," which is a surprising side effect for a function named `chargeOrder`.
- **Type mismatch risk:** `order.total` is used instead of the previously-used `order.totalMinor`; nothing in this diff (or the visible codebase) shows an `Order.total` string field being introduced. If `Order` doesn't declare `total`, this won't compile; if it does, mixing a decimal `total` field alongside `totalMinor` in the same model is itself a hazard worth flagging to the type's owner.
- **No error handling for `parseFloat`:** if `order.total` is malformed, `parseFloat` returns `NaN` silently rather than throwing, so a bad order could be charged as `NaN` amount with no validation.
- **No tests included** for the changed charge behavior (amount computation, currency, logging, idempotency) — given this touches money and PII, test coverage should be mandatory before merge.

## Questions for the author

- Is `order.total` actually a new field on `Order`, and if so, why introduce a decimal/string total alongside the existing `totalMinor` instead of extending `totalMinor`?
- Is the shipping fee intentionally added here, and should it vary by currency/region rather than being a hard-coded `4.99`?
- Why was `idempotencyKey` removed — was this intentional or an accidental drop during a refactor?