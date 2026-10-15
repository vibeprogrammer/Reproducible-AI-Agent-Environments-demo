# Chapter 2 demo: Build a Reusable Agent Skill

Companion demo for Chapter 2 of *Reproducible AI Agent Environments*. It
assembles Meridian's `meridian-code-review` skill in a fresh workspace,
validates it against the Agent Skills specification, runs its checker
script against two sample diffs, and installs the published package with
APM v0.33.0.

The published package lives in this repository at
[`packages/meridian-code-review/`](../packages/meridian-code-review/) and is
tagged `meridian-code-review-v1.0.0`. In the book, this public repository
stands in for Meridian's internal `meridian-finance` repositories.

## Prerequisites

- Linux or macOS with `bash`, `git`, and Python 3.11+ (`python3 -m venv` must
  work; the skill's own script needs only Python 3.9+ and the standard
  library).
- APM **0.33.0** on `PATH` (`apm --version`). The harness refuses any other
  version.
- Network access to `github.com` (APM fetches the tagged package; pip fetches
  the reference validator) and to PyPI (the validator's two dependencies,
  `click` and `strictyaml`).

## Files

| Path | What it is |
|------|------------|
| `run.sh` | The automated demo (sources `../scripts/lib.sh`) |
| `fixtures/base/src/checkout/charge.ts` | A small `meridian-checkout` source file before the change |
| `fixtures/bad.diff` | A change that breaks all four money rules |
| `fixtures/good.diff` | A similar change that keeps them |

## Run it

```bash
bash ch02-build-a-reusable-agent-skill/run.sh
```

Evidence lands in `evidence/ch02-build-a-reusable-agent-skill/`
(`transcript.log`, `environment.txt`, `result.json`, `artifacts/`).

## What it checks (expected observations)

1. **Assemble** the skill folder: `SKILL.md`, `apm.yml`,
   `scripts/check_money_rules.py`, `references/money-rules.md`,
   `references/false-positives.md`, `assets/review-report-template.md`.
   `SKILL.md` is 72 lines.
2. **Validate** with `skills-ref` (the specification's reference validator,
   pinned to commit `69ef37e9424c` of agentskills/agentskills): `Valid skill`.
   Two broken copies fail: a directory name that does not match `name`, and a
   `SKILL.md` without `description`.
3. **Scan** `SKILL.md` and a reference file with `apm audit --file`: no
   issues found.
4. **Run the checker** inside its own folder: `bad.diff` gives 6 findings
   (MR001 x3, MR002, MR003, MR004) and exit 1; `good.diff` gives 0 and exit 0;
   JSON output reports `"count": 6`; stdin and whole-file modes work; bad
   input exits 2. SHA-256 snapshots of the folder before and after are
   identical, so the script wrote nothing.
5. **Install** `vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-code-review#meridian-code-review-v1.0.0`
   with `--target claude,copilot` into an empty project. The skill lands in
   `.claude/skills/meridian-code-review/` and
   `.agents/skills/meridian-code-review/`, byte-identical to the source; the
   lockfile records `resolved_ref: meridian-code-review-v1.0.0` and the commit.
   The installed script still finds the 6 issues.
6. **Install at user scope** (`apm install -g ... --target claude`): the
   skill lands in `~/.claude/skills/meridian-code-review/` (inside the
   isolated demo HOME) and nothing is written to the current project.

## Limitations: what this demo does NOT verify

- **Activation by a real agent.** Nothing here proves that Claude Code,
  GitHub Copilot or any other harness picks the skill for a review request,
  follows its workflow, or writes a good report. That needs a model and an
  authenticated harness; Chapter 3 covers activation testing.
- **The checker's coverage.** It is a line-based pattern matcher. It does
  not catch whole objects passed to a logger, keys injected by a wrapper, or
  float arithmetic on values that were never named like money. See
  `references/false-positives.md` in the package.
- **Other targets.** Only `claude` and `copilot` (project) and `claude` (user
  scope) are exercised. Chapter 6 builds the cross-target matrix.
- **`allowed-tools`.** The skill does not declare it; the field is
  experimental in the specification and harness support varies.
