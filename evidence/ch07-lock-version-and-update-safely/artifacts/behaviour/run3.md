## Code review: `change.diff` — checkout charge rewrite

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (single file: `src/checkout/charge.ts`)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `order.total` is parsed with `parseFloat`, converting the order amount from the project's integer `amountMinor` model to a float | Keep using `order.totalMinor` (an integer), as the old code did |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal literal fed directly into the payment amount | Express as minor units, e.g. `const shippingFeeMinor = 499;`, and add it to `amountMinor` |
| MR001 | src/checkout/charge.ts:9 | `amount: amount + shippingFee` sends a floating-point sum to `paymentsClient.payments.create`, and the request shape no longer matches `CreatePaymentRequest`, which expects `amount: Money` (`{ amountMinor, currency }`), not a bare float | Build a `Money` value: `money(order.totalMinor + shippingFeeMinor, "EUR")` and pass that as `amount` |
| MR002 | src/checkout/charge.ts:8-12 | The `idempotencyKey` field present in the original code has been deleted from the `payments.create` call; `createPayment` throws if it's missing, but `paymentsClient.payments.create` may be a different, non-enforcing wrapper, so this is a real regression that lets a retried request double-charge the card | Restore `idempotencyKey: order.id` (or the stable key used elsewhere) on the create call |
| MR003 | src/checkout/charge.ts:7 | `card.number` (the raw PAN) is logged in full via `logger.info("charging card", { cardNumber: card.number, ... })` | Drop the card number from the log entirely, or log a masked last-4 if traceability is needed; log the order ID / payment ID instead |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 codes | Use `"EUR"` |

## Checker findings dismissed

- None. The sixth checker hit (`amount.toFixed(2)` at line 13) was reviewed against the "display code" exception in `references/false-positives.md`, but `amount` here is not derived from minor units — it's the already-corrupted float from line 5 — so it's kept as part of the MR001 finding at line 5 rather than treated as a separate violation.

## Other findings

- **Unapproved scope creep:** adding a hard-coded `shippingFee` inside the charge function silently changes what the customer is billed, with no indication this was the intent of the change. This looks like it may not belong in this diff at all.
- **Type mismatch:** `paymentsClient.payments.create` is called with `amount` (a number) instead of the `Money` object (`{ amountMinor, currency }`) the rest of the codebase uses (see `src/payments/create-payment.ts`); as written this likely won't type-check.
- **No tests included** for the changed charge behavior (amount computation, currency, idempotency key).

## Questions for the author

- Is adding a shipping fee an intended part of this change, or should it be reverted/moved to its own PR?
- Where does `order.total` (string) vs `order.totalMinor` (integer) come from — was `totalMinor` removed from the `Order` type, or is this an accidental downgrade?
- What does `paymentsClient.payments.create` actually expect for `amount`/`currency` — does it match the `CreatePaymentRequest`/`Money` shape used elsewhere in the repo?