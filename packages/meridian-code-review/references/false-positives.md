# Deciding whether a checker finding is real

The checker matches text patterns on single lines. Use this guide before
dropping a finding.

- **MR001 on display code.** `price.toFixed(2)` inside a template that
  formats an integer-derived value for a receipt is display, not
  arithmetic. Drop it only if the value came from minor units and is not
  fed back into a calculation.
- **MR001 on names that are not money.** `feeRate = 0.029` is a rate, not
  an amount. Drop it, and suggest a name that does not look like money if
  the confusion is likely to recur.
- **MR002 when the key is set elsewhere.** The key may be added by a
  wrapper (for example a payment client that injects it from request
  context) or passed more than eight lines below the call. Find the code
  that sets it before dropping the finding; if you cannot find it, keep it.
- **MR003 on masked values.** A value that is already masked (last-4 only)
  is acceptable. The checker skips lines that mention `last4`, `masked` or
  `redact`; anything else needs a human look.
- **MR004 on test data.** A lower-case code in a test that checks input
  validation is intentional. Drop it when the test asserts a rejection.

When you drop a finding, say so in the report's "Checker findings dismissed"
section with one line of reasoning. A silent drop hides the decision from
the human reviewer.
