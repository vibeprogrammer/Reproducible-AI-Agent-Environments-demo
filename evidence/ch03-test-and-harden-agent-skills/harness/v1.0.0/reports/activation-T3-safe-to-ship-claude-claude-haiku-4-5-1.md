**⛔ Changes requested — do not ship.**

This change introduces **four critical violations** of Meridian's money rules and is unsafe to deploy.

## Money Rule Violations

| Line | Rule | Finding | Fix |
|------|------|---------|-----|
| 11–12, 16 | **MR001** (Integer minor units) | Amount calculated using `parseFloat()` and floating-point arithmetic (`amount + 4.99`). Floating-point math causes precision loss and rounding errors in financial transactions. | Convert `order.total` to integer minor units (e.g., cents). Add shipping fee as `5000` minor units, not `4.99`. Remove `parseFloat()`. |
| 20 (removed) | **MR002** (Idempotency key required) | `idempotencyKey` parameter removed from `paymentsClient.payments.create()`. Without this, duplicate requests (network retry, client retry) will charge the customer multiple times. | Restore: `idempotencyKey: order.id,` |
| 13 | **MR003** (No card data in logs) | `logger.info("charging card", { cardNumber: card.number, ... })` logs the full card number. This is PCI-DSS and GDPR violation. | Remove `cardNumber` from the log. Log the payment ID or masked last-4 instead if needed for debugging. |
| 18 | **MR004** (Currency uppercase) | `currency: "eur"` uses lowercase. ISO 4217 requires uppercase alphabetic codes. | Change to `currency: "EUR"` |

## Impact

- **MR001 + MR002 together**: Customers could be charged $X.XX instead of the integer minor-unit amount, and may be double-charged due to missing idempotency.
- **MR003**: Card data exposure violates PCI compliance and customer privacy.
- **MR004**: Payment provider rejection or silent currency mismatch.

All four issues must be fixed before this can merge.