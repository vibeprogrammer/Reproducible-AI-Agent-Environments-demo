# Regression suite: meridian-code-review

Deterministic checks for the `meridian-code-review` skill
(`packages/meridian-code-review/`). Standard-library Python 3.9+, no network,
writes nothing outside a temporary directory, finishes in a few seconds.

```bash
python3 tests/meridian-code-review/run_suite.py \
  --skill-dir packages/meridian-code-review --expect-version 1.0.1
```

`--skill-dir` can also point at an installed copy, for example
`.claude/skills/meridian-code-review` after `apm install`, which is how
Chapter 3 tests a published tag rather than the working tree.

What it checks:

- **Structure and metadata:** frontmatter present; `name` follows the Agent
  Skills naming rule and matches the folder; description length and a
  "Use when" clause; body under 500 lines; `metadata.version` in SKILL.md
  equals `version` in apm.yml.
- **Resources:** every `scripts/`, `references/` and `assets/` path named in
  SKILL.md exists, and no bundled resource is unreferenced.
- **Checker contract:** exit codes (0 clean, 1 findings, 2 usage or input
  error), `--help` text that describes diff mode truthfully, and the fixture
  diffs in `fixtures/` with the findings listed in `expectations.json`. Two
  fixtures pin known limitations (a false positive and a false negative) so
  that changing them is a decision, not an accident.
- **Side effects:** the checker runs under a Python audit hook that records
  any open-for-write, socket, subprocess or file-system mutation event; the
  skill folder and the working directory are hashed before and after.

The suite lives outside the package folder on purpose: APM v0.33.0 copies the
whole package folder into each consumer's skills directory, so tests and
deliberately bad fixtures inside it would ship to every developer.

Behavioural tests in real agent harnesses (activation, report format,
conflicting instructions, permissions) are in
`ch03-test-and-harden-agent-skills/harness/`; they need model credentials
and report pass rates, not a single pass/fail.
