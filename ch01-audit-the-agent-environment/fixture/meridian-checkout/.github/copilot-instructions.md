# Copilot instructions for meridian-checkout

You are working on Meridian's checkout payment service (TypeScript, Node.js).

- Represent money as an integer number of minor units (`amountMinor`).
  Never use floating-point numbers for amounts.
- Every call that creates a payment must carry an idempotency key.
- Never log card data or personal data (PII), not even in debug logs.
- Currency codes are ISO 4217 alphabetic codes (for example `EUR`, `NOK`).
- Prefer small, pure functions and explicit return types.
