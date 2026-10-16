---
description: Meridian payment conventions for every payment service
applyTo: "src/**/*.ts"
---

- Money is an integer count of minor units (`amountMinor: number`).
  Never use floats for amounts, fees, or totals.
- Every call that creates, captures, or authorizes a payment carries an
  idempotency key. Reuse the caller's key on retries; never generate a
  fresh one inside a retry loop.
- Never log card data or customer PII, not even partially or masked.
  Log payment and order IDs instead.
- Currency codes are ISO 4217 strings such as `"EUR"` or `"NOK"`.
- When a rule cannot be followed, say so in the pull request and name
  the reason. Do not work around it silently.
