## Code review: charge.ts — switch to float amount + shipping fee

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** not run — Bash access denied in this session; reviewed manually against `references/money-rules.md`

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:20 (removed) | The `idempotencyKey: order.id` field is deleted from the `payments.create` call. A retry after a network timeout can now create a duplicate charge. | Restore `idempotencyKey: order.id` on the create call. |
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` replaces the existing `order.totalMinor` integer field with a float parsed from a decimal string — exactly the pattern this rule bans. | Keep using `order.totalMinor` (integer minor units); if a shipping fee must be added, add it in minor units too. |
| MR001 | src/checkout/charge.ts:12 | `const shippingFee = 4.99` is a decimal money literal used directly in arithmetic. | `const shippingFeeMinor = 499` (or wherever the real minor-unit value comes from). |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` sends a floating-point dollar amount to `payments.create`, and renames the field from `amountMinor` to `amount`, losing the minor-unit contract entirely. | `amountMinor: order.totalMinor + shippingFeeMinor`. |
| MR003 | src/checkout/charge.ts:13 | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number (PAN) before the charge is even attempted. | Drop `cardNumber` from the log, or log a masked last-4 if a card reference is needed: `{ last4: card.number.slice(-4), orderId: order.id }`. |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` is lower-case; Meridian's boundary requires upper-case ISO 4217 codes. | `currency: "EUR"`. |

## Checker findings dismissed

- None — checker script wasn't run (Bash tool denied this session); all findings above were confirmed by manual read of the diff.

## Other findings

- Line 22's `amount.toFixed(2)` for the `display` log field would normally be fine (display formatting is allowed by the rules), but here it's irredeemably tainted since `amount` itself is already a float parsed from a string (line 11) rather than derived from integer minor units — fixing MR001 upstream also fixes this.
- The diff silently changes the public shape of the `payments.create()` call (`amountMinor` → `amount`, dropping `idempotencyKey`). If `paymentsClient` has a typed interface, this should fail to compile; if it's loosely typed (e.g. `any`), it will instead fail silently at the payment provider or double-charge customers — worth checking which is true before this merges.
- No test changes accompany a change that alters the charge amount, currency casing, and idempotency behavior — all three deserve regression tests.

## Questions for the author

- Why was `idempotencyKey` removed — intentional, or a merge/rebase accident?
- Where should `shippingFee` actually come from — is 4.99 meant to be a hard-coded placeholder, or should it be read from `order` / a pricing service in minor units?
- Is the `cardNumber` log line intentional for debugging, or should it be removed before this ships? Logging PANs may also be a PCI-DSS violation beyond Meridian's own rule.