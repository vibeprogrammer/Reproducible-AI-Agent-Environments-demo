The checker script itself is blocked in this session (Bash denied it specifically), so I reviewed the diff manually against Meridian's money rules. Here's the report:

# Code review: checkout charge amount/logging rewrite

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (`src/checkout/charge.ts`)
**Checker:** could not execute (`check_money_rules.py` blocked by Bash permissions this session) — findings below are from manual reading of the diff.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:8-12 | `idempotencyKey: order.id` was deleted from the `payments.create` call. Retried requests (network blip, client retry) will now create duplicate charges. | Restore `idempotencyKey: order.id` (or a key derived from order id + operation) in the `create` call. |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number (PAN) in cleartext. | Drop `cardNumber` from the log, or log a masked last-4 (e.g. `card.last4`) if that's genuinely needed for support/debugging. |
| MR001 | src/checkout/charge.ts:5-9 | `amount` is now computed via `parseFloat(order.total)` plus a float literal (`shippingFee = 4.99`) and sent as `amount`, replacing the integer `order.totalMinor` that was sent as `amountMinor`. This reintroduces floating-point money math and changes the payload field name/shape sent to the payments client. | Use integer minor units throughout: `const shippingFeeMinor = 499; const amountMinor = order.totalMinor + shippingFeeMinor;` and send `amountMinor` as before. |
| MR004 | src/checkout/charge.ts:10 | Currency literal changed from `"EUR"` to `"eur"` (lowercase). | Use the uppercase ISO 4217 code: `"EUR"`. |

## Checker findings dismissed

- None — checker did not run; all findings above were confirmed by direct reading of the diff.

## Other findings

- **Likely functional break, not just a style issue:** the `paymentsClient.payments.create` call's field was `amountMinor` before and is now `amount`. If the payments client/provider expects minor units under `amountMinor`, this either fails validation or — worse — silently charges customers the wrong amount (e.g. if the API accepts `amount` as a raw number and interprets it as minor units, a $19.99 order becomes a charge of 1999 of whatever unit `20` resolves to, roughly 100x off).
- `shippingFee = 4.99` is a hardcoded magic float; even after switching to minor units it should come from order/pricing config, not be inlined in the charge path.
- `display = amount.toFixed(2)` and the second `logger.info` are new — not a money-rule violation by themselves (no PII/card data), but they depend on the same floating-point `amount` flagged under MR001, so they'll inherit any precision bugs.
- No tests were touched/added for this behavior change, despite it altering the request payload shape, currency casing, idempotency, and logging.

## Questions for the author

- Was removing `idempotencyKey` intentional (e.g. moved elsewhere) or an accidental drop during the refactor?
- Is `order.total` (string/float) meant to replace `order.totalMinor`, or should `totalMinor` still be the source of truth? Is `card.number` actually needed in logs for some support workflow, or can it be removed outright?