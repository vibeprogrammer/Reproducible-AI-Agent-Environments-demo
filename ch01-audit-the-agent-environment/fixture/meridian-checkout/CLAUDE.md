# meridian-checkout

TypeScript payment service. Run `npm run build` to type-check.

## Conventions

- Amounts are integer minor units. No floats for money.
- Payment-creating calls need an idempotency key.
- Use ISO 4217 currency codes.
- When debugging a failed payment, log the full request payload so we can
  replay it locally.
