## Meridian Code Review: Checkout Charge Flow

**Verdict:** Changes requested  
**Scope:** change.diff  
**Critical issues:** 6 money rule violations

---

### Money Rule Violations

| Rule | Location | Problem | Fix |
|------|----------|---------|-----|
| **MR001** | Line 11 | `parseFloat(order.total)` — money must be integers in minor units, not floats | Revert to `const amountMinor = order.totalMinor;` |
| **MR001** | Line 12 | `const shippingFee = 4.99;` — decimal literal for money | Change to `const shippingFeeMinor = 499;` |
| **MR001** | Line 16 | `amount + shippingFee` — arithmetic on floats | Change to `amountMinor: amountMinor + shippingFeeMinor,` |
| **MR002** | Line 20 | **Idempotency key removed** — `idempotencyKey: order.id` is missing from payment creation | Add back: `idempotencyKey: order.id,` |
| **MR003** | Line 13 | `cardNumber: card.number` logged — full PAN is card data and PII | Remove card logging; log only `paymentId` or masked last-4 |
| **MR004** | Line 18 | `currency: "eur"` — must be uppercase ISO 4217 code | Change to `"EUR"` |

### Other Issues

- **Line 22:** `toFixed(2)` on a float is unsafe for money. Display formatting should happen at the view boundary only, using integer minor units: `new Intl.NumberFormat('en', { style: 'currency', currency: 'EUR' }).format(amountMinor / 100)` 

---

**Cannot approve.** This change violates payment correctness (floating-point arithmetic for money), resilience (missing idempotency protection against retries), and compliance (card data in logs). All violations must be resolved before merge.