---
name: meridian-code-review
description: >-
  Review a code change in a payment service against Meridian's money rules:
  amounts as integer minor units (never floating point), an idempotency key
  on every call that creates a payment, charge or refund, no card data or
  other PII in logs, and ISO 4217 currency codes. Use when the user asks for
  a code review, PR or diff feedback, or a pre-merge check on TypeScript or
  JavaScript code that handles money, payments, refunds or checkout.
license: MIT
compatibility: >-
  The checker script needs Python 3.9 or newer (standard library only) and
  read access to the diff or files under review. No network access.
metadata:
  owner: meridian-finance/agent-tooling
  version: "1.0.0"
---

# Meridian code review

Review the change the user points you at (a diff, a pull request, staged
changes or a list of files) for Meridian's money rules first, then for
general correctness. Produce one report in the format of
`assets/review-report-template.md`.

## Workflow

1. **Get the change as a unified diff.** Prefer `git diff --unified=3
   <base>...HEAD` or the diff the user supplied. If you only have files,
   review the files.
2. **Run the checker.** Save the diff to a file, then run:

   ```bash
   python3 scripts/check_money_rules.py --diff change.diff
   ```

   For whole files use `--files path/one.ts path/two.ts`. Add
   `--format json` when you want machine-readable findings. Exit code 0
   means no findings, 1 means findings, 2 means the script could not run
   (bad arguments or unreadable input). The script only reads; it never
   edits files or calls the network.
3. **Confirm every finding by reading the code.** The checker is a
   pattern matcher, not a type checker. For each finding, decide whether it
   is a real violation, then keep it or drop it. If you are unsure whether a
   finding is a false positive, LOAD `references/false-positives.md`.
4. **Review what the checker cannot see.** Read the changed code for the
   rules in `references/money-rules.md` (LOAD it when the change touches
   amounts, currencies, payment or refund creation, or logging), then for
   ordinary correctness: error handling, tests for the changed behaviour,
   and naming.
5. **Write the report** using `assets/review-report-template.md`. Put money
   rule violations first, each with file, line, rule ID and a concrete fix.

## Rules at a glance

| ID | Rule | Typical fix |
|----|------|-------------|
| MR001 | Money is an integer count of minor units (cents, ore) | `amountMinor: 1999` instead of `amount: 19.99` |
| MR002 | Every payment, charge or refund creation sends an idempotency key | pass `idempotencyKey` derived from the order or request |
| MR003 | Never log card data or personal data | log a payment ID or a masked last-4 |
| MR004 | Currency codes are ISO 4217 alphabetic codes in upper case | `"EUR"`, not `"eur"` or `"€"` |

## Boundaries

- Do not modify code during the review unless the user asks you to fix
  findings. Suggest the change in the report instead.
- Do not approve a change that still has a confirmed MR001-MR003 finding;
  mark the verdict "Changes requested".
- Project-specific facts (service names, which client wraps the payment
  provider, the logger in use) come from the repository's own instructions,
  not from this skill. If they conflict with this skill on a money rule,
  report the conflict instead of choosing silently.
