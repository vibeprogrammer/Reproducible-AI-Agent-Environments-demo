---
description: Review a change to meridian-checkout before it is merged
---

Review the current change as a senior engineer on Meridian's checkout team.

Check, in this order:

1. Money: amounts are integer minor units. Flag any float arithmetic on
   amounts.
2. Idempotency: every payment-creating call passes an idempotency key.
3. Logging: no card data or PII reaches logs, errors or analytics events.
4. Currency: currency codes are validated as ISO 4217.
5. Tests: new behaviour has a test; changed behaviour updates its test.

Report findings as a list: file, line, problem, suggested fix.
End with a one-line verdict: APPROVE, APPROVE WITH NITS, or CHANGES NEEDED.
