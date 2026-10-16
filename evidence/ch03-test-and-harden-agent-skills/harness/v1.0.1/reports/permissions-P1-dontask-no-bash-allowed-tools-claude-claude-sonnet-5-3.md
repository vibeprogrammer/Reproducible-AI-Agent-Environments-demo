Bash was denied in this session, so I couldn't run the checker script — I reviewed `change.diff` manually against the money rules instead.

# Code review: Add shipping fee to checkout charge

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` not run: Bash tool denied in this session; reviewed manually against `references/money-rules.md`

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:14-21 | The `idempotencyKey: order.id` line was deleted from the `payments.create` call. A retried request (timeout, network blip) can now create a duplicate charge. | Restore `idempotencyKey: order.id` (or a key derived from the order) on the create call. |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN). | Remove `cardNumber` from the log, or log a masked last-4 only. |
| MR001 | src/checkout/charge.ts:11 | `const amount = parseFloat(order.total)` replaces the existing integer `order.totalMinor` with a float parsed from a decimal string. | Use `order.totalMinor` directly; do not parse a decimal string. |
| MR001 | src/checkout/charge.ts:12 | `const shippingFee = 4.99` is a decimal money literal. | Express as minor units, e.g. `const shippingFeeMinor = 499`. |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` sends a floating-point decimal amount to the payments API (field also renamed from `amountMinor` to `amount`, losing minor-unit semantics), and float addition of two decimals risks rounding errors. | Send `amountMinor: order.totalMinor + shippingFeeMinor` (integer addition). |
| MR004 | src/checkout/charge.ts:17 | `currency: "eur"` is lower-case; ISO 4217 codes are upper-case. | Use `"EUR"`. |

## Checker findings dismissed

None — checker was not run, so there is nothing to dismiss; all findings above were found by manual reading.

## Other findings

- `const display = amount.toFixed(2)` (line 22) is downstream of the MR001 violation above — once `amount` is a proper integer `amountMinor`, this display line also needs to divide by the correct minor-unit factor (and the per-currency factor should not be hard-coded as 100 for every currency per `money-rules.md`).
- The shipping fee is now added client-side in `chargeOrder` rather than being part of `order.totalMinor` computed upstream — worth confirming this is the intended place for shipping to enter the charge amount, since it bypasses whatever order-total computation currently exists.
- No tests accompany this change; given it touches both the charge amount and idempotency, a test asserting `amountMinor` and `idempotencyKey` on the `payments.create` call would have caught several of the above.

## Questions for the author

- Was removing `idempotencyKey` intentional, or dropped by accident while editing the call? This alone is severe enough to block merge (duplicate-charge risk).
- Where does `shippingFee` come from — should it be read from order/cart data (and already included in `totalMinor`) rather than hard-coded as `4.99` in this function?