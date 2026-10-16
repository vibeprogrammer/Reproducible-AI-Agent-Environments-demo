Now I'll compile the code review report based on my analysis of the diff against Meridian's money rules.

## Code review: charge.ts payment changes

**Verdict:** Changes requested

**Scope reviewed:** change.diff (src/checkout/charge.ts)

**Checker:** Manual review (4 confirmed violations)

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11-12, 16 | Amount uses floating-point arithmetic instead of integer minor units. `parseFloat(order.total)` converts to float, and `4.99` is added via `amount + shippingFee`. Money must be stored and computed as integers (e.g., cents). | Use `order.totalMinor` directly. Add shipping fee as an integer minor unit: `const shippingFeeMinor = 499;` and `amount: amountMinor + shippingFeeMinor`. |
| MR002 | src/checkout/charge.ts:14-19 | Idempotency key removed from `paymentsClient.payments.create()` call. Every call that creates a payment must include `idempotencyKey` to ensure retries don't create duplicate charges. | Restore: `idempotencyKey: order.id,` as a parameter in the create call. |
| MR003 | src/checkout/charge.ts:13 | Card number logged: `{ cardNumber: card.number, ... }`. Full card numbers (PAN) must never be logged—this is PII and a compliance violation. | Remove `cardNumber` from the log. Log only the payment ID or order ID: `logger.info("charging card", { orderId: order.id });` |
| MR004 | src/checkout/charge.ts:18 | Currency code is lowercase `"eur"`. ISO 4217 codes must be uppercase. | Change to `currency: "EUR"` |

## Other findings

- **Line 22–23**: The `display` value is derived from a float, not from integer minor units. Once amounts are properly stored as integers, display formatting should use `Intl.NumberFormat` on the integer minor unit value (divided by the appropriate factor for the currency).

- **Missing refactoring**: If `order.total` is already a float but should be `order.totalMinor`, this suggests a data model issue upstream. Confirm that the Order type has an integer `totalMinor` field or equivalent.

---

**Summary:** This change introduces four critical violations of Meridian's money handling rules: floating-point arithmetic for amounts, missing idempotency key, logging of card data, and a non-standard currency code. All four must be fixed before merge.