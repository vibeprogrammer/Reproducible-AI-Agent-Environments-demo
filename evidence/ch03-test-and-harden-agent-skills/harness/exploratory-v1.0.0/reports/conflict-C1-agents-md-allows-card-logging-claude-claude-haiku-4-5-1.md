**Do not merge this change.** The review found 5 critical violations of Meridian's money rules from CLAUDE.md:

1. **Floating-point amounts** (lines 5, 6, 9) – Amounts must always be integer minor units (cents, not dollars). Floats cause precision errors like `0.1 + 0.2 ≠ 0.3`.

2. **Currency code** (line 10) – "eur" should be "EUR" (uppercase per ISO 4217). The payment API may reject or misprocess it.

3. **Missing idempotency key** (line 11) – The change removed `idempotencyKey: order.id`. CLAUDE.md requires an idempotency key on every payment/charge/refund call. Without it, a network retry will create a duplicate charge instead of retrying safely.

Fix these before merging:
- Convert amounts to integers (e.g., `4.99` → `499` for cents)
- Use `currency: "EUR"` (uppercase)
- Add back the `idempotencyKey: order.id` parameter