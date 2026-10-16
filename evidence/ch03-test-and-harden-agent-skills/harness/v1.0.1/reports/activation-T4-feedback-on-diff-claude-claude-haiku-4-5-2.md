I'll do a manual review since the checker needs approval. Based on my analysis of the diff against Meridian's money rules, here's my report:

---

# Code review: checkout charge flow

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** Not run (manual review)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11 | `parseFloat(order.total)` converts a decimal string to a float; money must stay as integer minor units | Use `order.totalMinor` (the existing field) instead |
| MR001 | src/checkout/charge.ts:12 | Hardcoded decimal literal `4.99` for shipping fee; must be an integer minor unit | Change to `const shippingFee = 499;` (or derive the correct integer value) |
| MR002 | src/checkout/charge.ts:14–21 | Payment creation call is missing `idempotencyKey`; this was removed on line 20 | Re-add `idempotencyKey: order.id,` to the create call |
| MR003 | src/checkout/charge.ts:13 | Logging full card number (`cardNumber: card.number`) exposes PAN | Log payment ID or masked last-4 instead; remove `cardNumber` |
| MR004 | src/checkout/charge.ts:18 | Currency code is lower-case `"eur"`; ISO 4217 requires upper-case | Change to `currency: "EUR"` |
| MR001 | src/checkout/charge.ts:16 | Adding two floats (`amount + shippingFee`) violates money-as-integers rule | Compute as `amountMinor: order.totalMinor + shippingFee` with both as integers |

## Other findings

- **Line 22:** `amount.toFixed(2)` on a float is a smell. Display formatting should always derive from an integer minor-unit amount, formatted via `Intl.NumberFormat` at the UI edge, not in business logic.

## Questions for the author

- Why was the idempotency key removed? This is required by Meridian's API for every payment creation to ensure retries don't double-charge.

---

**Summary:** This change violates four of the four critical money rules. It replaces type-safe integer minor units with floating-point arithmetic, removes the idempotency key, logs card data, and uses a lower-case currency code. Please revert to the original pattern: use `order.totalMinor`, add the fee as an integer, restore the idempotency key, remove the card logging, and keep currency codes upper-case.