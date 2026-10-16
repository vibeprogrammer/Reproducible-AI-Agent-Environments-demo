This confirms the pre-diff state is the "safe" version — the change regresses on every money rule at once.

# Code review: chargeOrder regresses to float amounts, drops idempotency, logs PAN

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` not run (Bash denied in this session); reviewed manually against `references/money-rules.md`. 5 violations confirmed.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:12 (create call) | `idempotencyKey: order.id` is removed entirely from the `payments.create` call. A network retry after a timeout can now create a duplicate charge. | Restore `idempotencyKey: order.id` (or another stable, order-derived key) on the create call. |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN). | Drop `cardNumber` from the log, or log a masked last-4 only if genuinely needed. |
| MR001 | src/checkout/charge.ts:5-9 | `amount = parseFloat(order.total)` parses a decimal string, and `shippingFee = 4.99` is a decimal literal; `amount + shippingFee` does float arithmetic on money and is sent as `amount` instead of integer minor units. This replaces a correct `order.totalMinor` field with float math — classic rounding-error risk (e.g. `0.1 + 0.2` style drift) and loses the `amountMinor` naming contract. | Keep amounts as integers in minor units end-to-end: `const shippingFeeMinor = 499; paymentsClient.payments.create({ amountMinor: order.totalMinor + shippingFeeMinor, ... })`. |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 codes. | Use `"EUR"`. |

## Checker findings dismissed

None — the checker could not be run in this session, so no automated findings were available to triage. All findings above were found by manual inspection against `references/money-rules.md`.

## Other findings

- `display = amount.toFixed(2)` at line 13 is downstream of the already-invalid float `amount`; once `amount` is restored to integer minor units, this line should be removed (format for display from the minor-unit value at the point of display/logging, not carried as a separate float).
- `shippingFee` is a hardcoded magic number baked into `chargeOrder`; even once converted to minor units, consider sourcing it from the order/config rather than hardcoding a fee inside the charge path.
- The function silently changed from a pure pass-through of a precomputed total (`order.totalMinor`) to doing fee arithmetic inline — if `order.total`/`order.totalMinor` already includes shipping upstream, this change would double-charge shipping. Worth confirming with the author.
- No tests accompany this diff despite touching the charge path end-to-end (amount, currency, idempotency, logging all changed).

## Questions for the author

- Does `order.total`/`order.totalMinor` already include shipping? If so, adding `shippingFee` here double-charges it.
- Was removing `idempotencyKey` intentional, or dropped accidentally while refactoring the create call's fields?
- Is `card.number` logging leftover debug code meant to be removed before merge?