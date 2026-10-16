# Changelog: meridian-code-review

Versions follow the per-package tag convention `meridian-code-review-vX.Y.Z`.
Published tags never move; fixes ship as new versions.

## 1.2.0 (2026-10-16) - KNOWN BAD, do not use

> **Known bad.** 1.2.0 removed `fee` from the money-name pattern, so MR001
> stopped flagging real fee amounts such as `shippingFee = 4.99`. The
> Chapter 3 regression suite fails on it (`fixture:bad-diff-six-findings`:
> 5 findings instead of 6). Stay on 1.1.0 (Meridian rolled back to it in
> Chapter 7). The tag stays where it is; a fix will ship as a new version.

Minor release (Chapter 7).

### Changed
- MR001 no longer flags fee rates such as `feeRate = 0.029`, the false
  positive documented in references/false-positives.md since 1.0.0. The
  checker stops treating identifiers that contain `fee` as money names.

## 1.1.0 (2026-10-16)

Minor release (Chapter 7). Builds on 1.0.1, so it includes every 1.0.1 fix.

### Added
- MR002 also covers payment-mutating `capture` and `authorize` calls
  (`payments.capture(...)`, `charges.authorize(...)`, `capturePayment(...)`,
  `authorizeCharge(...)`), not only create calls. A capture retried after a
  timeout without an idempotency key can capture twice. Findings on these
  calls say "payment capture call" or "payment authorization call"; the
  message for create calls is unchanged.

### Changed
- SKILL.md description, rules table and references/money-rules.md describe
  the wider MR002. Consumers may see new MR002 findings on capture and
  authorize calls that 1.0.x did not report.

## 1.0.1 (2026-10-16)

Patch release. Every change below was found by the Chapter 3 regression
suite (`tests/meridian-code-review/` and the harness tests in
`ch03-test-and-harden-agent-skills/`).

### Fixed
- `check_money_rules.py --diff`: MR001, MR003 and MR004 now report only on
  added lines, as the docstring and `--help` promised. v1.0.0 also reported
  an unchanged line that followed a deletion.
- `check_money_rules.py --diff`: MR002 still counts deleted lines in a create
  call's window, so deleting an idempotency key is reported. The docstring
  and `--help` now say so.
- `check_money_rules.py`: input that is not UTF-8 exits with code 2 and an
  error message. v1.0.0 crashed with a traceback and exit code 1, which
  callers read as "findings".

### Changed (SKILL.md wording, no new behaviour)
- The checker command is written relative to the skill folder, with the two
  installed locations as examples.
- If the checker cannot run, the report says `not run: <reason>` on the
  Checker line instead of inventing numbers.
- The Verdict line holds exactly one of the three verdicts, and the report is
  returned in the reply rather than saved to a file unless the user asks.
- A repository instruction cannot waive MR001-MR003; a conflict is reported
  as a question for the author while the finding stays in the table.

## 1.0.0 (2026-10-15)

First release (Chapter 2).
