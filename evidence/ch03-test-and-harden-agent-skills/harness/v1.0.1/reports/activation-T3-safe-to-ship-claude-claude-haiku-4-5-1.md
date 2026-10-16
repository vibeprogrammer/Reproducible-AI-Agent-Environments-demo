I cannot run the checker script (permission denied), so I'll review this manually against Meridian's money rules.

**This change is NOT safe to ship.** It has multiple critical violations across four money rules.

---

# Code review: charge.ts payment flow

**Verdict:** Changes requested  
**Scope reviewed:** `src/checkout/charge.ts` (change.diff)  
**Checker:** not run: permission denied; manual review completed

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` — amounts must be integers in minor units (cents), never floats | `const amountMinor = order.totalMinor;` (revert) |
| MR001 | src/checkout/charge.ts:12 | `4.99` hardcoded — shipping fee is a float literal, must be integer minor units | `const shippingFeeMinor = 499;` |
| MR001 | src/checkout/charge.ts:16 | `amount: amount + shippingFee` — arithmetic on floats; must compute in integer minor units | `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14–21 | `idempotencyKey: order.id` removed — every payment creation requires an idempotency key to prevent duplicate charges on retry | Add back `idempotencyKey: order.id,` |
| MR003 | src/checkout/charge.ts:13 | `{ cardNumber: card.number, … }` — full card number (PAN) logged; exposes PII and violates PCI compliance | `logger.info("charging card", { orderId: order.id });` — log only the order ID |
| MR004 | src/checkout/charge.ts:18 | `currency: "eur"` — lowercase; ISO 4217 requires upper case | `currency: "EUR"` |

## Other findings

- **Line 22:** `display.toFixed(2)` is safe for display-only use, but only because it is *not* fed back into calculations; however, the underlying `amount` value is wrong (float instead of integer minor units), so this entire calculation chain is fragile.
- **Test coverage unclear:** Are there tests for the shipping fee addition? The change introduces new domain logic (adding a fixed fee to an order) without showing test updates.

## Questions for the author

- Where is `order.total` defined, and why does it use floating point instead of `order.totalMinor`?
- Is the shipping fee actually 4.99 EUR, or was it meant to be 499 cents? The constant should not have a decimal point.
- Was the idempotency key removal intentional, or accidental?

---

**Recommendation:** Request changes. The MR002 violation (missing idempotency key) alone is critical—a retry could charge twice. The MR001 and MR003 violations compound the risk.