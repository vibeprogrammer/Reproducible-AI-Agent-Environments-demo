---
description: Extra checks for changes to payment-creating and refund code paths
applyTo: "src/payments/**/*.ts"
---

- A change to a payment-creating or refund path names the idempotency key
  it reuses and the retry behaviour in the pull request description.
- New amount fields are integer minor units and carry the ISO 4217
  currency code beside them; never infer the currency from the account.
- Add or update a test that replays the same request twice with the same
  idempotency key and asserts a single charge or refund.
- Ask a second payments engineer to review any change to settlement or
  refund rounding.
