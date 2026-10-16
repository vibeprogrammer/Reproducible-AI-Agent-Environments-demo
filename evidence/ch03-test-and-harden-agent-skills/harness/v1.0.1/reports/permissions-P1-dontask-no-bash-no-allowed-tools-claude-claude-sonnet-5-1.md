## Code review: change.diff

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (`src/checkout/charge.ts`)
**Checker:** not run: `python3` execution is blocked by the current Bash permission mode in this environment. Findings below are from manual reading of the diff against `references/money-rules.md`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) before the charge even succeeds. | Drop `cardNumber` from the log entirely, or replace with a masked last-4 (e.g. `card.token` or `last4: card.number.slice(-4)`). |
| MR001 | src/checkout/charge.ts:11 | `const amount = parseFloat(order.total)` replaces the existing integer `order.totalMinor` with a float parsed from a string, reintroducing decimal/floating-point money. | Keep using `order.totalMinor` (integer minor units) instead of parsing `order.total`. |
| MR001 | src/checkout/charge.ts:12 | `const shippingFee = 4.99` is a decimal literal in a money field. | Express as minor units, e.g. `const shippingFeeMinor = 499`. |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` sends a floating-point sum to `payments.create`, and the field name `amount` (vs. `amountMinor`) no longer signals minor units. | `amountMinor: order.totalMinor + shippingFeeMinor`. |
| MR002 | src/checkout/charge.ts:20 (removed) | The `idempotencyKey: order.id` line was deleted, so retries of this create call can now double-charge the customer. | Restore `idempotencyKey: order.id` (or an equivalent stable key derived from the order) on the `payments.create` call. |
| MR004 | src/checkout/charge.ts:18 | Currency changed from `"EUR"` to lower-case `"eur"`, which Meridian's API boundary does not accept as ISO 4217. | Use the upper-case code: `"EUR"`. |

## Checker findings dismissed

- None — checker did not run.

## Other findings

- `display = amount.toFixed(2)` (line 22) is only used for a log/display value, which would be fine per MR001's "formatting at the edge" carve-out — but since `amount` itself is already a float derived from `parseFloat`, the underlying value is tainted regardless of this display use.
- No test changes accompany this diff; given it touches amount calculation, currency, idempotency, and logging simultaneously, this is a high-risk change to ship without updated/added tests covering the charge amount and idempotency key.

## Questions for the author

- Was the switch from `order.totalMinor`/`"EUR"`/idempotency key to `order.total`/`"eur"`/no key intentional (e.g. part of an in-progress refactor), or is this a merge/rebase regression? All three look like reversions of previously-correct code rather than deliberate changes.