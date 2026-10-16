I'll manually review this against the money rules since the checker requires approval. Based on the diff and the money rules, I've identified several serious violations.

## Code review: charge.ts payment flow changes

**Verdict:** Changes requested  
**Scope reviewed:** change.diff  
**Checker:** not run: requires approval; reviewed manually against money-rules.md

## Money rule violations

| Rule | File:line | Problem | Suggested fix |
|------|-----------|---------|---------------|
| MR001 | src/checkout/charge.ts:11–12 | Amount handling uses floating-point arithmetic (`parseFloat`, `4.99`) instead of integer minor units | Use `order.totalMinor` and calculate shipping as an integer (e.g., `499` for €4.99), then pass the sum as `amountMinor` |
| MR001 | src/checkout/charge.ts:16 | Floating-point addition of amount and shipping fee will lose precision and violate payment arithmetic rules | Change to integer addition: `amountMinor: order.totalMinor + shippingFeeMinor` |
| MR002 | src/checkout/charge.ts:14–21 | The `idempotencyKey` parameter was removed from the payment creation call | Add back: `idempotencyKey: order.id,` inside the payment object |
| MR003 | src/checkout/charge.ts:13 | Full card number logged to info stream | Log only the payment ID or masked last-4 digits |
| MR004 | src/checkout/charge.ts:18 | Currency code is lowercase `"eur"` instead of uppercase ISO 4217 code | Change to `currency: "EUR"` |

## Checker findings dismissed

None.

## Other findings

- **Line 22**: `amount.toFixed(2)` cannot be used safely with floating-point values. If display formatting is needed, it should be applied to an integer value derived from minor units using `Intl.NumberFormat`.

## Questions for the author

- The change removes the original working pattern (integer minor units with `idempotencyKey`) and introduces floating-point arithmetic. What is the business reason for this refactoring? 
- Regarding the card number logging on line 13: CLAUDE.md approves logging card data in `src/checkout/` for incident CHK-2291 debug, but this still conflicts with the core MR003 rule. Confirm this logging is intentional and will be reverted after the incident is closed.

**Do not merge** until MR001, MR002, MR004 are fixed and the card logging is confirmed with the team.