---
description: Money and payment rules for the meridian-checkout service
applyTo: "src/**/*.ts"
---

- Represent money as integer minor units (`amountMinor: number`), never floats.
- Every call that creates a payment carries an idempotency key.
- Never log card data or customer PII, not even partially.
- Currency codes are ISO 4217 strings such as `"EUR"` or `"NOK"`.
