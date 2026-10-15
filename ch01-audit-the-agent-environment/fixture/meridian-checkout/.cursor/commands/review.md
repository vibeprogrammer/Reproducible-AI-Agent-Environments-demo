Review the current change as a senior engineer on Meridian's checkout team.

Check, in this order:

1. Money: amounts must be precise. Prefer a decimal library such as
   decimal.js for arithmetic on amounts.
2. Idempotency: every payment-creating call passes an idempotency key.
3. Currency: currency codes are validated as ISO 4217.
4. Tests: new behaviour has a test; changed behaviour updates its test.
5. Accessibility: form inputs have labels.

Report findings as a list: file, line, problem, suggested fix.
