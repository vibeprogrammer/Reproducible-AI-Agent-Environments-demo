All six checker findings check out against the code — this diff is a significant regression from a previously-correct implementation. Here's the report:

---

# Code review: checkout charge flow

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 | `parseFloat(order.total)` replaces the existing `order.totalMinor` integer with a float parsed from a decimal string | Keep using `order.totalMinor` directly; don't reintroduce a float path |
| MR001 | src/checkout/charge.ts:6 | `shippingFee = 4.99` is a decimal money literal fed into the charge amount, not a rate | Define `shippingFeeMinor = 499` and add it to the minor-unit total |
| MR003 | src/checkout/charge.ts:7 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full PAN | Drop `cardNumber` entirely, or log `card.token`/a masked last-4 instead |
| MR002 | src/checkout/charge.ts:8 | `idempotencyKey: order.id` was removed from `payments.create()` | Restore `idempotencyKey: order.id` on the create call |
| MR004 | src/checkout/charge.ts:10 | `currency: "eur"` is lower-case | Use `"EUR"` |
| MR001 | src/checkout/charge.ts:13 | `amount.toFixed(2)` formats the already-broken float `amount`, not a value derived from minor units, and is then logged | Once amount math is fixed to use minor units, derive any display string from `totalMinor` via a proper currency formatter, not `toFixed` on a hand-parsed float |

## Checker findings dismissed

None — all 6 checker findings are real violations.

## Other findings

- This diff removes a correct, working implementation (`order.totalMinor`, upper-case `"EUR"`, `idempotencyKey: order.id`) and replaces it with a broken one. It looks like a regression rather than a forward change — worth checking whether this was merged from a stale branch or an accidental revert.
- `amount + shippingFee` is floating-point decimal arithmetic on money (e.g. `0.1 + 0.2` rounding errors) — a second-order consequence of MR001 that compounds the bug: the charged amount can be off by a cent from what's displayed/expected.
- No tests accompany this change; the original file apparently had none either, but given the surface area (charge amount, currency, PCI logging) this is a good place to add a unit test asserting `payments.create` is called with the correct integer `amountMinor`, upper-case currency, and a stable `idempotencyKey`.

## Questions for the author

- Is `shippingFee` meant to be a new feature (adding shipping to the charge), or is this diff unintentionally reverting a previous fix? The combination of regressions (float amount, lower-case currency, dropped idempotency key, raw PAN logging) looks more like a bad merge/rebase than a deliberate change.
- Where does `order.total` (the string/decimal field) come from, and is `order.totalMinor` still the source of truth elsewhere in the codebase? If both fields exist, the diff should keep using the minor-unit one.