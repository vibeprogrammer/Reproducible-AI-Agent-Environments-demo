All 6 checker findings are real — this diff takes a previously-correct implementation and reintroduces every money-rule violation Meridian checks for.

# Code review: checkout charge flow

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `order.total` is parsed with `parseFloat`, replacing the prior `order.totalMinor` integer field with a lossy float derived from a decimal string | Keep `const amountMinor = order.totalMinor;` — don't reintroduce the string/float path at all |
| MR001 | src/checkout/charge.ts:12,16 | `shippingFee = 4.99` is a decimal literal added directly to `amount` before sending it to the payments API | Use an integer minor-unit constant, e.g. `shippingFeeMinor = 499`, and add it to `amountMinor` |
| MR002 | src/checkout/charge.ts:14-21 | `paymentsClient.payments.create(...)` no longer passes `idempotencyKey` (it was `order.id` before and has been deleted) | Restore `idempotencyKey: order.id` on the create call so a retry after a timeout can't double-charge |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN) | Remove `cardNumber` entirely, or log a masked last-4 only if truly needed |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; was `"EUR"` before this change | Use the upper-case ISO 4217 code `"EUR"` |
| MR001 | src/checkout/charge.ts:22 | `amount.toFixed(2)` formats `amount`, but `amount` is the already-corrupted float from line 11, not a value derived from integer minor units — this isn't legitimate display formatting, it's formatting a broken calculation | Fixed automatically once line 11/16 go back to integer minor units; display should derive from `amountMinor`, e.g. `(amountMinor / 100).toFixed(2)` with a currency-aware divisor |

**None dismissed** — every checker finding is a genuine regression, not a false positive. (Checked against the false-positive guide: the `toFixed` isn't display-only formatting of a minor-units value, since its input is already floating-point; the idempotency key isn't set elsewhere in the diff; `"eur"` isn't test data.)

## Checker findings dismissed

None — all 6 confirmed.

## Other findings

- **API contract change, not just a money-rule bug:** the field sent to `paymentsClient.payments.create` changed from `amountMinor` to `amount` (line 15→16). If the payments client's type/API expects `amountMinor`, this diff likely fails to compile or silently sends the wrong field — worth confirming against the client's type definition.
- **This whole diff reads as a regression of a correct implementation**, not a new feature: every line it touches un-does a rule the original code satisfied (integer minor units, idempotency key, upper-case currency). Worth asking whether this was accidentally reverted from an older branch/commit rather than written fresh.
- No tests were included in the diff for `chargeOrder`; given the behavior change (float arithmetic, dropped idempotency key), this is exactly the kind of change that should have a test asserting the amount sent is an integer and that `idempotencyKey` is present.

## Questions for the author

- Does `order.total` (string, decimal) even exist as a field, or was `order.totalMinor` renamed/removed upstream and this is a mechanical but wrong adaptation?
- Is the second `logger.info("charged", ...)` call on line 23 new? It logs `payment.id` and `display` only, which is fine on its own, but it's downstream of the broken `amount`/`display` chain above.
- Was dropping `idempotencyKey` intentional (e.g. moved into a wrapper) or an accidental deletion? If a wrapper sets it, point me to that code and I'll drop the MR002 finding.