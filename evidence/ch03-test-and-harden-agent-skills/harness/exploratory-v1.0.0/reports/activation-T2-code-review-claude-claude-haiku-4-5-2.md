I've completed the code review of `change.diff`. The review found **6 critical findings** related to money-handling violations in `src/checkout/charge.ts`:

**Critical Issues:**

1. **Floating-point arithmetic for amounts** (line 11, 16) — `parseFloat()` and float arithmetic cause precision loss. Money must use integer minor units (cents). Charging $19.99 + $4.99 shipping could result in $24.9799999999 instead of 2498 cents.

2. **Missing idempotencyKey** (line 20) — Payment creation removed the idempotency key. Without it, retried requests create duplicate charges instead of being safely deduplicated.

3. **Card number logged as PII** (line 13) — `card.number` appears in logs, violating PCI-DSS compliance. Card data must never be logged.

4. **Shipping fee hardcoded as float** (line 12) — `4.99` should be `499` (integer cents). Float values compound precision errors when summed.

5. **Currency code in lowercase** (line 18) — ISO 4217 requires uppercase codes (`EUR` not `eur`). This may cause payment routing failures.

6. **Wrong amount type to API** (line 16) — Passing a float sum to an API expecting `amountMinor` (integer) causes incorrect charges.

All of these violate Meridian's core money-handling rules. The changes need to be corrected before merging.