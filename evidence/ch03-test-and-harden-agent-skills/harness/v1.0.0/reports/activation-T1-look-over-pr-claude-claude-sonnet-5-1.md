## Code review: `src/checkout/charge.ts` — charge amount/currency changes

**Verdict:** Changes requested
**Scope reviewed:** change.diff (1 file: `src/checkout/charge.ts`)
**Checker:** `check_money_rules.py` found 6 findings, 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | charge.ts:5 | `amount = parseFloat(order.total)` replaces the existing integer `order.totalMinor` with a floating-point parse of a decimal string | Keep using `order.totalMinor` (integer minor units); drop `parseFloat` entirely |
| MR001 | charge.ts:6 | `shippingFee = 4.99` is a decimal literal mixed into the charge amount | Use `shippingFeeMinor = 499` and add it to `amountMinor` as integers |
| MR002 | charge.ts:8 | `idempotencyKey: order.id` was removed from the `payments.create()` call | Restore `idempotencyKey: order.id` (or a key derived from the order) on the call |
| MR003 | charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the raw card number | Remove `cardNumber` from the log, or replace with a masked last-4 if a card reference is genuinely needed |
| MR004 | charge.ts:10 | `currency: "eur"` is lower-case | Use `"EUR"` |
| MR001 | charge.ts:13 | `display = amount.toFixed(2)` formats the float `amount`, which is also fed into the arithmetic for the actual charge (`amount + shippingFee`) — not display-only | Compute any display string from the integer minor-unit total (e.g. `(amountMinor / 100).toFixed(2)`), after the amount itself is fixed to be an integer |

## Checker findings dismissed

None — all 6 checker findings are real violations (confirmed against `references/false-positives.md`; the `toFixed` case doesn't qualify for the display-code exception because `amount` is fed back into the charge calculation, not derived from minor units).

## Other findings

- The core issue is that this diff reintroduces floating-point money (`parseFloat`, a float `shippingFee`, `toFixed`) into a function that previously did everything correctly in integer minor units. This isn't just a style nit — `0.1 + 0.2`-style rounding errors on `amount + shippingFee` can under/overcharge customers by a cent, silently.
- Removing `idempotencyKey` also opens the door to duplicate charges on retry, which combined with the floating-point math is a meaningful regression on a checkout path.
- No test changes accompany this diff; given it touches charge amount, currency, and idempotency, I'd expect at least one test asserting the final amount sent to `paymentsClient.payments.create()`.

## Questions for the author

- Why was `order.totalMinor` abandoned in favor of parsing `order.total` as a float? Is there a new requirement (e.g., shipping fee) that could instead be added in minor units to `order.totalMinor`?
- Is the `cardNumber` logging intentional for some debugging effort, or leftover/accidental? It should not ship either way.

---
Bottom line: this diff should not merge as-is — it reintroduces float money math, drops the idempotency key, logs a raw card number, and lower-cases the currency code. Happy to apply the fixes directly if you want me to patch `charge.ts`.