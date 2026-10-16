## Code review: `src/checkout/charge.ts` — checkout charge rewrite

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` converts the order total to a floating-point number instead of using the existing integer minor-units field | Use `order.totalMinor` directly, as the previous version did |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a money amount expressed as a float literal, not an integer count of minor units | `const shippingFeeMinor = 499;` |
| MR002 | src/checkout/charge.ts:8-12 | `idempotencyKey: order.id` was removed from the `payments.create` call — this is a regression from the current code | Restore `idempotencyKey: order.id` (or a key derived from the order) on the create call |
| MR003 | src/checkout/charge.ts:7 | Full card PAN (`card.number`) is logged in plaintext | Drop `cardNumber` from the log, or log a masked last-4 (`card.last4`) if needed for support |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` uses a lower-case code; ISO 4217 codes are upper-case | `currency: "EUR"` |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` formats a value that was never in minor units (see line 5) and is sent to `payments.create` as `amount + shippingFee`, i.e. it's fed into the charge math, not just a receipt display | Fixed automatically once `amount`/`shippingFee` are tracked as integer minor units; compute any display string from the minor-unit total divided appropriately, not from a float |

## Checker findings dismissed

None — all 6 checker findings are confirmed real violations.

## Other findings

- The rewrite silently drops the previously-correct `amountMinor` field and the idempotency key while introducing float arithmetic for the charge amount — this is a strict regression in a payment path, not just a style issue. The diff should be rejected rather than patched piecemeal.
- `order.total` (string) vs `order.totalMinor` (integer) — no validation or error handling if `order.total` is malformed or `parseFloat` returns `NaN`; another reason to use the existing minor-units field instead.
- No tests are included for this change; given it touches charge amount, currency, idempotency, and logging simultaneously, this needs test coverage for the restored integer-minor-units path and a negative test asserting no card PAN appears in logs.

## Questions for the author

- Why was `order.totalMinor` replaced with `parseFloat(order.total)` and a hard-coded `shippingFee`? Is shipping fee calculation meant to move into this function, and if so, is there an integer minor-units source for it elsewhere (e.g., `order.shippingFeeMinor`)?
- Was the card-number log line added for a specific debugging need? If so, a masked/last-4 alternative should cover it.