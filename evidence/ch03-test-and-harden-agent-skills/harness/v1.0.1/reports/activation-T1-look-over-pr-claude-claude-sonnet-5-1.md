Here's the review.

# Code review: Checkout charge update

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` 6 finding(s), 6 confirmed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR002 | src/checkout/charge.ts:10 (diff) | `idempotencyKey: order.id` was deleted from the `payments.create` call, so charges are no longer idempotent — a retry will double-charge the customer. | Restore `idempotencyKey: order.id` (or a key derived from the order) on the create call. |
| MR003 | src/checkout/charge.ts:13 (diff) | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number. | Drop `cardNumber` entirely, or log a masked last-4 (e.g. `card.number.slice(-4)`) with a field named so the MR003 masked-value exception clearly applies. |
| MR001 | src/checkout/charge.ts:11 (diff) | `order.totalMinor` (an integer minor-unit field) was replaced with `parseFloat(order.total)`, reintroducing floating-point money and losing precision guarantees. | Go back to `order.totalMinor` as the base amount. |
| MR001 | src/checkout/charge.ts:12 (diff) | `shippingFee = 4.99` is a decimal float added directly into the charge amount. | Express as a minor-unit integer, e.g. `shippingFeeMinor = 499`, and add it to `order.totalMinor`. |
| MR001 | src/checkout/charge.ts:22 (diff) | `amount.toFixed(2)` formats the already-tainted float `amount` for the "charged" log. Per the skill's own guidance this is only safe to drop when the value originates from minor units and isn't fed back into a calculation — here it's the same float used in the actual charge, not a minor-units-derived display value. | Once `amount`/`shippingFee` are fixed to minor units above, derive any display string from the minor-unit integer (e.g. `(amountMinor / 100).toFixed(2)`) instead of carrying a float through the whole function. |
| MR004 | src/checkout/charge.ts:18 (diff) | `currency: "eur"` is lower-case; was previously the correct `"EUR"`. | Revert to `currency: "EUR"`. |

## Checker findings dismissed

None — all 6 checker findings were confirmed by reading the surrounding code.

## Other findings

- This diff is a straight regression from a previously-correct implementation (`src/checkout/charge.ts` on disk already does `amountMinor`, `"EUR"`, and `idempotencyKey: order.id` correctly) — every change in the PR moves away from the money rules rather than toward a new feature. Worth confirming this is the intended branch/diff, since it reads like an accidental revert or a copy from an older/wrong source file.
- No tests were added or updated for the new shipping-fee behavior, and the function's return/error handling is unchanged, so there's nothing to verify the new `shippingFee` logic even does what's intended.

## Questions for the author

- Is `order.total` (string) actually a supported field on `Order`, or was this meant to stay as `order.totalMinor`? The current repo's `Order`/`CardInput` types weren't found in `src/`, so I couldn't confirm `order.total`'s shape — worth double-checking it even compiles.
- Was the shipping fee supposed to come from a minor-unit field elsewhere (e.g. `order.shippingFeeMinor`) rather than a hardcoded `4.99` literal?

**Bottom line:** this PR shouldn't merge as-is — it drops idempotency protection, logs raw card numbers, and reverts integer money handling back to floats, all of which are exactly the failure modes Meridian's money rules exist to prevent.