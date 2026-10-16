No `Order`/`CardInput` type declarations exist elsewhere in the repo, so I can't confirm `order.total` is even a valid field. Noting that as an open question. Here's the review:

Note: `scripts/check_money_rules.py` couldn't be run — Bash is disabled in this session (don't-ask mode denial). The findings below come from a manual read of the diff against `money-rules.md`, cross-checked with `false-positives.md`.

# Code review: charge.ts — switch to float amount, drop idempotency key

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** not run (Bash unavailable this session) — manual review only

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` replaces the existing `order.totalMinor` integer field with a float parsed from a decimal string | Keep using `order.totalMinor` (integer minor units); don't reintroduce `parseFloat` |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal money literal fed into arithmetic | Use `shippingFeeMinor = 499` |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` sends a float sum to `payments.create`, and the field is renamed from `amountMinor` to `amount`, losing the minor-unit contract | Send `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:20 (removed) | `idempotencyKey: order.id` was deleted from the `payments.create` call; a retry after a timeout can now double-charge the customer | Restore `idempotencyKey: order.id` on the create call |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Drop `cardNumber` entirely, or log a masked last-4 if a card reference is needed |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 | Use `currency: "EUR"` |

## Checker findings dismissed

None — checker did not run, so no findings to dismiss.

## Other findings

- `amount.toFixed(2)` on line 22 is used only to build a log message (`display`), not fed back into the charge arithmetic, so it isn't a second MR001 instance on its own — but it depends on `amount` already being a float (see MR001 above), so fixing MR001 removes the need for this line too.
- The function silently changes its contract: it used to charge exactly `order.totalMinor`; now it unconditionally adds a hard-coded `4.99` shipping fee with no apparent sourcing from the order, and no indication this is intentional scope for this change.
- No test changes accompany this diff; given it touches the charge amount, currency case, and removes idempotency, this is exactly the kind of change that needs a regression test (e.g., asserting the create call still receives `idempotencyKey` and an integer `amountMinor`).

## Questions for the author

- Is `order.total` (string, decimal) actually a field on `Order`, or was this meant to stay `order.totalMinor`? I could not find the `Order` type definition in the repo to confirm `total` exists.
- Why was `idempotencyKey` removed from the create call — intentional or accidental during the refactor?
- Is adding a hard-coded shipping fee in scope for this change, and if so, where should `shippingFeeMinor` come from (order, config, a rate card)?