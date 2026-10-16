## Code review: `change.diff` (src/checkout/charge.ts)

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (1 file: `src/checkout/charge.ts`)
**Checker:** `scripts/check_money_rules.py` — 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR003 | src/checkout/charge.ts:7 | Full card number (`card.number`) is logged in plaintext — a PCI/PII violation, and the most severe issue in this diff | Drop `cardNumber` from the log entirely, or log a masked last-4 only (e.g. `card.last4`) |
| MR002 | src/checkout/charge.ts:8-11 | `idempotencyKey: order.id` was deleted from the `payments.create()` call and not replaced; a retried request can now double-charge the customer | Restore `idempotencyKey: order.id` (or another stable per-order key) on the create call |
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` turns the order total into a floating-point decimal instead of using the existing `order.totalMinor` integer | Use `order.totalMinor` directly, as the previous version did |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal money literal, and it's added to a float amount — classic floating-point arithmetic risk (e.g. `0.1 + 0.2`-style rounding errors) on a charge amount | Express as minor units, e.g. `const shippingFeeMinor = 499;`, and add to `amountMinor` as integers |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` is applied to the same float used in the charge arithmetic (not a minor-units value formatted for display only), so this is float arithmetic leaking into a display path, not safe display formatting | Derive `display` from the integer minor-units amount (e.g. `(amountMinor / 100).toFixed(2)`) after the fix above |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case; ISO 4217 codes must be upper-case | `currency: "EUR"` |

## Checker findings dismissed

None — all 6 checker findings were confirmed by reading the code.

## Other findings

- **Field rename risk:** `amount: amount + shippingFee` sends a field named `amount` to `paymentsClient.payments.create()` where the original code sent `amountMinor`. If the client/API expects minor units under `amountMinor`, this is not just a money-format bug but likely a wrong-field-name bug (the API may ignore it, error, or misinterpret units). Confirm the payment client's expected field name as part of fixing MR001.
- **No tests included:** the diff doesn't touch or add tests for `chargeOrder`, despite changing the amount calculation, currency, and idempotency behavior — all security/money-critical paths. Tests should cover: correct minor-unit total, idempotency key presence, and no PII in logs.
- **Hardcoded shipping fee:** `shippingFee = 4.99` is a hardcoded magic number sitting in the charge function rather than coming from `order` — worth asking about separately from the float/int issue.

## Questions for the author

- Why was `order.totalMinor` replaced with `parseFloat(order.total)`? Was `order.totalMinor` removed from the `Order` type, or is this an unintended regression?
- Why was `idempotencyKey` dropped from the `payments.create()` call — intentional, or a merge/refactor accident?
- Is the `cardNumber` log line temporary debug code that should never have been committed? It should not ship regardless of intent.