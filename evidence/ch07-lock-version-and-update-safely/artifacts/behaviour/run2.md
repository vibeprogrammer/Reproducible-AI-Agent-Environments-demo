## Code review: `change.diff` — `src/checkout/charge.ts`

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (single file: `src/checkout/charge.ts`)
**Checker:** `scripts/check_money_rules.py` 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` turns an integer minor-units amount back into a float; the original code already had `order.totalMinor` ready to use. | Keep using `order.totalMinor` directly; drop the `parseFloat` call entirely. |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal added straight into the payment amount, and it's hard-coded regardless of order currency (some currencies have 0 or 3 decimals, see `references/money-rules.md`). | Express the fee as `shippingFeeMinor = 499` (int, in minor units for the order's currency) and add it to `amountMinor`, not to a float. |
| MR002 | src/checkout/charge.ts:14-20 | `idempotencyKey: order.id` was removed from the `payments.create` call. A retried request after a network timeout can now charge the customer twice. `src/payments/create-payment.ts` shows this field is required elsewhere in the codebase and throws without it. | Restore `idempotencyKey: order.id` on the create call. |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 codes per `.claude/rules/money-handling.md`. | Use `currency: "EUR"`. |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN). This is the most severe finding in the diff. | Remove `cardNumber` from the log entirely; log `order.id` (and `card.token`/a masked last-4 if a reference is needed) only. |
| MR001 | src/checkout/charge.ts:22 | `display = amount.toFixed(2)` formats the already-invalid float `amount` (not a value derived from `amountMinor`), and the result is then logged, not just shown in a UI. It's a downstream symptom of the same root cause as the first finding. | Once `amountMinor` is restored, derive any display string from it via a proper minor-units formatter (e.g. `Intl.NumberFormat`), not `toFixed` on a float. |

## Checker findings dismissed

None — all 6 checker findings are confirmed real violations.

## Other findings

- The payload key itself changed from `amountMinor` to `amount` (line 15-16). Even after fixing the float issue, this silently changes the field name sent to `paymentsClient.payments.create`, which likely breaks the provider contract or type checking against `Money`/`amountMinor` conventions used elsewhere in the repo (`src/money.ts`).
- The second `logger.info("charged", { paymentId, display })` call is new and not harmful by itself (no PII), but it depends on the tainted `display` value above.
- Adding a shipping fee inside `chargeOrder` is a business-logic change beyond what the diff's intent (presumably "charge the order") suggests — pricing composition like this is usually expected to happen before checkout, not be hard-coded into the charge call. Worth confirming this is actually wanted.
- No test changes accompany a diff that touches amount calculation, currency, idempotency, and logging — all four are exactly the areas Meridian's money rules exist to guard.

## Questions for the author

- Why was `idempotencyKey` dropped — intentional, or a merge/rebase accident?
- Is adding `shippingFee` in `chargeOrder` intended, and if so, should it vary by currency/locale instead of being a fixed `4.99`?
- Was the card-number log line added for debugging and meant to be removed before merge?