All 6 checker findings are real violations confirmed by reading the code — this diff also regresses a previously-correct implementation (the "before" code already used minor units, uppercase currency, and an idempotency key). Not safe to ship.

# Code review: Charge order — add shipping fee

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` converts money to a float; the old code used `order.totalMinor` directly | Keep using `order.totalMinor` (integer minor units); drop `parseFloat` entirely |
| MR001 | src/checkout/charge.ts:6 | `const shippingFee = 4.99` is a decimal literal used as money | Use `shippingFeeMinor = 499` and add to `amountMinor` |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` formats a float as display money, compounding the float conversion from line 5 | Not needed if amounts stay in minor units end-to-end; format for display only at the edge, from the integer minor value |
| MR002 | src/checkout/charge.ts:8 | `paymentsClient.payments.create({...})` no longer passes `idempotencyKey` — it was removed from the previous version | Restore `idempotencyKey: order.id` (or a key derived from the order) on the create call |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number | Remove `cardNumber`, or log a masked last-4 (e.g., `card.number.slice(-4)`) instead |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; was `"EUR"` before this change | Use `"EUR"` (upper-case ISO 4217) |

## Checker findings dismissed

None — all 6 findings confirmed by reading the diff.

## Other findings

- The new `amount` field sent to `paymentsClient.payments.create` is also a field-name change from `amountMinor` to `amount`. Even after fixing MR001, confirm the payments client's schema still expects `amountMinor` — sending a renamed field silently could cause the provider to receive the wrong value or reject the request.
- The diff removes the old, correct implementation wholesale (integer minor units, uppercase currency, idempotency key) rather than extending it — this looks like a regression from a rewrite rather than an intentional change to any one of these behaviors.
- No test changes accompany this diff; given it touches charge creation, a unit test asserting `amountMinor`, `currency`, and `idempotencyKey` on the outgoing payload would have caught all of MR001/MR002/MR004 here.

## Questions for the author

- Why was `order.totalMinor` replaced with `parseFloat(order.total)` — is there a new `order.total` (decimal string) field that's meant to replace `totalMinor`, or was this an unintentional revert to float math?
- What is the intent of logging `display` and `cardNumber` — is this temporary debug logging that should be stripped before merge?

**Not safe to ship as-is.** Three independent money-rule violations (float arithmetic, missing idempotency key, raw card number in logs) plus a lower-case currency code — any one of these would block merge on its own.