The checker script execution was denied by permission settings, so I'll note that and rely on manual review (I've already read the full diff and relevant rule references).

---

# Code review: Add shipping fee to card charge

**Verdict:** Changes requested
**Scope reviewed:** change.diff (src/checkout/charge.ts)
**Checker:** `scripts/check_money_rules.py` not run: Bash execution of the script was denied by permission settings; findings below are from manual inspection against `references/money-rules.md`.

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:5 (`const amount = parseFloat(order.total)`) | Regression from integer minor units (`order.totalMinor`) to a float parsed from a decimal string. Floating-point arithmetic on money reintroduces rounding errors. | Keep `order.totalMinor` as the integer source of truth. |
| MR001 | src/checkout/charge.ts:6, 9 (`shippingFee = 4.99`, `amount: amount + shippingFee`) | Decimal literal added via float arithmetic into the amount sent to the payment API, instead of an integer minor-units value (e.g. `shippingFeeMinor = 499`). | `const shippingFeeMinor = 499; amountMinor: order.totalMinor + shippingFeeMinor`. |
| MR002 | src/checkout/charge.ts:8-12 (`paymentsClient.payments.create({...})`) | `idempotencyKey: order.id` was removed from the create call. A retry after a network timeout can now create a duplicate charge. | Restore `idempotencyKey: order.id` (or another stable key derived from the order) on the create call. |
| MR003 | src/checkout/charge.ts:7 (`logger.info("charging card", { cardNumber: card.number, orderId: order.id })`) | Logs the full card number (PAN) before the charge is attempted. | Drop `cardNumber` entirely, or log a masked last-4 (`card.number.slice(-4)`) if a reference is needed. |
| MR004 | src/checkout/charge.ts:10 (`currency: "eur"`) | Currency code must be the upper-case ISO 4217 code; lower-case is not accepted at the API boundary. | `currency: "EUR"`. |

## Checker findings dismissed

None — checker did not run, so there are no automated findings to dismiss.

## Other findings

- The field sent to `paymentsClient.payments.create` changed from `amountMinor` to `amount`. Even after fixing MR001/MR002, confirm the payments client's type still accepts this shape — as written it both uses the wrong unit and (likely) the wrong field name for the API.
- `display = amount.toFixed(2)` at line 13 is derived from the already-incorrect float `amount`, so it inherits the MR001 problem; once `amount` is replaced with an integer minor-units value, compute the display string from that integer (e.g. via a shared money-formatting helper) rather than from a float.
- No error handling was added or changed; out of scope for this diff but note the removed idempotency key makes a retry-without-dedup bug much more likely to trigger in practice (e.g. a caller retrying on timeout).

## Questions for the author

- Why was `idempotencyKey` dropped — was this intentional (e.g. moved to a wrapper not shown in this diff), or an accidental omission during the shipping-fee change? If a wrapper sets it, point to that code so the finding can be re-checked.
- Is `order.total` (string, parsed with `parseFloat`) a new field, or should this still be reading `order.totalMinor`? The diff looks like it swapped a correct integer source for a decimal-string one without being asked to.