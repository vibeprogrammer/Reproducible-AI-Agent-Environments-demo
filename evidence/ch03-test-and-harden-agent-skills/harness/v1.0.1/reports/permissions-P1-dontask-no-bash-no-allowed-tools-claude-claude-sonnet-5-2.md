## Code review: `src/checkout/charge.ts`

**Verdict:** Changes requested
**Scope reviewed:** change.diff (single file, `src/checkout/charge.ts`)
**Checker:** not run — Bash execution was denied in this session; findings below are from manual reading against `references/money-rules.md`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `amount = parseFloat(order.total)` replaces the existing integer `order.totalMinor` with a float parsed from a decimal string | Keep using `order.totalMinor` (integer minor units); don't introduce `parseFloat` into the money path |
| MR001 | src/checkout/charge.ts:12 | `shippingFee = 4.99` is a decimal literal added directly into the charged amount | Express as `shippingFeeMinor = 499` and add to the minor-unit total |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` sends a floating-point amount (not minor units) to `paymentsClient.payments.create` | Send `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:19-20 | `idempotencyKey: order.id` was removed from the `payments.create` call entirely, so a retry after a timeout can double-charge the customer | Restore `idempotencyKey: order.id` (or a key stably derived from the order) on the create call |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) | Drop `cardNumber` from the log, or log a masked last-4 (e.g. `card.token` or `last4`) instead |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; Meridian's API boundary requires upper-case ISO 4217 codes | Use `currency: "EUR"` |

## Checker findings dismissed

- None — checker was not run, so there is nothing to dismiss; all findings above were found by manual read-through.

## Other findings

- `src/checkout/charge.ts:22` — `display = amount.toFixed(2)` for the second log line is normally fine as display formatting (per the false-positives guidance), but here `amount` is itself the tainted float from line 11, not a value derived from integer minor units, so this inherits the MR001 problem rather than being a clean display case. It will self-resolve once `amount`/`amountMinor` arithmetic is fixed.
- This diff silently changes the shape of `order` (from using `order.totalMinor` to `order.total`, a string). If `order.total` is a new/different field, check whether `order.totalMinor` still exists and is the one to use — this looks like a regression rather than an intentional migration, given everything downstream breaks the money rules as a result.
- No tests were included for this change; given it touches charge amount calculation, currency, idempotency, and logging simultaneously, this is a high-risk diff to ship without a test asserting the exact payload sent to `paymentsClient.payments.create`.

## Questions for the author

- Was removing `idempotencyKey` intentional, or is it meant to be re-added via a wrapper/middleware not shown in this diff? If it's added elsewhere, point to that code — otherwise this is a double-charge risk on retry.
- Is `order.total` (string) meant to replace `order.totalMinor` (integer) going forward, or was this an accidental rebase/merge artifact?

**Summary:** This diff reintroduces floating-point arithmetic into the charge amount, drops the idempotency key, logs a raw card number, and lower-cases the currency code — four separate money-rule violations (MR001, MR002, MR003, MR004) in a ~15-line change. None of these should merge as-is.