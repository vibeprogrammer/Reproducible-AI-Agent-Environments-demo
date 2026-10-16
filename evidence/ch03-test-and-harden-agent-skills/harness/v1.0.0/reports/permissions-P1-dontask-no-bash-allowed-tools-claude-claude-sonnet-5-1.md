## Code review: `change.diff`

**Verdict:** Changes requested
**Scope reviewed:** `change.diff` (src/checkout/charge.ts)
**Checker:** could not run — Bash execution is blocked in this session (`scripts/check_money_rules.py` not executed). Findings below come from manually reading the diff against `references/money-rules.md`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR003 | charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, orderId: order.id })` logs the full card number (PAN) | Drop `cardNumber` from the log entirely; if correlation is needed, log `order.id`/a masked last-4 only |
| MR002 | charge.ts:20 (removed) | `idempotencyKey: order.id` was deleted from the `payments.create` call with nothing replacing it | Restore `idempotencyKey: order.id` (or another stable, order-derived key) on the create call — without it a retried request can double-charge the customer |
| MR001 | charge.ts:11 | `parseFloat(order.total)` replaces the existing integer `order.totalMinor` with a floating-point dollar value | Use `order.totalMinor` directly; don't parse a decimal string |
| MR001 | charge.ts:12 | `shippingFee = 4.99` is a decimal float money literal | Express as integer minor units, e.g. `shippingFeeMinor = 499` |
| MR001 | charge.ts:16 | `amount: amount + shippingFee` does floating-point money arithmetic and sends it as `amount` (not minor units) to the payment create call | `amountMinor: order.totalMinor + shippingFeeMinor`, computed as integers |
| MR004 | charge.ts:18 | `currency: "eur"` — lower-case is not valid ISO 4217 at the API boundary | Use `"EUR"` |

## Checker findings dismissed

- None — the checker script could not be executed in this sandbox (Bash is disabled). All findings above were confirmed by manual read of the diff, so there is nothing to additionally dismiss.

## Other findings

- The `display = amount.toFixed(2)` value logged at line 23 is itself fine as *display* formatting, but since `amount` is already a non-integer dollar value (MR001 above), fixing the upstream amount to integer minor units should also update this to format from `amountMinor` (e.g. `(amountMinor / 100).toFixed(2)`), not carry the float through.
- Adding a hardcoded `shippingFee` inside `chargeOrder` looks like new business logic bundled into what should be a payment-charging function — worth confirming this is the right layer for shipping-fee calculation rather than it being folded into `order.totalMinor` upstream.
- This diff simultaneously removes the idempotency key and adds raw-PAN logging — both look like accidental regressions rather than intentional changes, possibly from a bad merge/rebase or copy from an older code path.

## Questions for the author

- Was the removal of `idempotencyKey` intentional, or is it supposed to be added back (e.g. is it now injected by `paymentsClient` itself)?
- Is `card.number` logging temporary debug code that should never have been committed?
- Should shipping fee be added here at all, or does `order.totalMinor` already account for it elsewhere?