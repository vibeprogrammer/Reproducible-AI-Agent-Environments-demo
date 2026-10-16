# Chapter 3: Test and Harden Agent Skills

Companion demo for *Reproducible AI Agent Environments*, Chapter 3. It tests
Meridian's `meridian-code-review` skill (Chapter 2) at two published tags,
`meridian-code-review-v1.0.0` and the patch release this chapter ships,
`meridian-code-review-v1.0.1`.

The public demo repository stands in for Meridian's internal capabilities
repository (`meridian-finance` in the book).

## What is here

| Path | What it is |
|------|------------|
| `../tests/meridian-code-review/` | The reusable deterministic regression suite (`run_suite.py`, fixtures, `expectations.json`). It lives outside the package folder because APM v0.33.0 copies the whole package folder to consumers. |
| `../.github/workflows/meridian-code-review-tests.yml` | CI: runs the suite on every push or pull request that touches the skill or its tests. |
| `run.sh` | The chapter demo: installs both tags with APM, runs the suite, negative controls, spec validation, and checks the committed harness evidence. |
| `harness/run_harness_tests.py` | Behavioural tests in real agent harnesses (Claude Code, Codex CLI): activation, report adherence, conflicting instructions, permissions. |
| `harness/cases.json` | The test tasks: 4 should-trigger, 4 near-miss, 1 conflict case, 1 permissions case. |
| `harness/summarize.py` | Prints a results file as a short table. |
| `fixtures/workspace/` | The small `meridian-checkout` workspace each harness run starts from. |
| `../evidence/ch03-test-and-harden-agent-skills/` | Transcript and results of `run.sh`, plus `harness/` with the harness results and every agent report. |

## Prerequisites

- APM **v0.33.0** on `PATH` (`apm --version`); `run.sh` refuses any other version.
- Python 3.9+ and Git. Network access to github.com (APM installs the tags; `skills-ref` is installed from a pinned commit).
- Optional, for harness tests only: Claude Code 2.1.301 and/or Codex CLI 0.163.0,
  and `ANTHROPIC_API_KEY` (optionally `ANTHROPIC_BASE_URL`) and/or
  `OPENAI_API_KEY` (optionally `OPENAI_BASE_URL`). The harness script writes a
  Codex `config.toml` into a temporary `CODEX_HOME` that points at
  `OPENAI_BASE_URL` (default `https://api.openai.com/v1`) with
  `wire_api = "responses"`.

## Run it

```bash
bash ch03-test-and-harden-agent-skills/run.sh
```

Expected: `== ch03-test-and-harden-agent-skills: passed (… passed, 0 failed) ==`.
Without credentials, step 7 prints `skipped: harness runs …` and only checks
the committed harness evidence; that is a pass, not a failure.

To run the harness tests yourself (costs model tokens; about 87 agent runs
with the defaults):

```bash
RUN_HARNESS_TESTS=1 HARNESS_RUNS=3 bash ch03-test-and-harden-agent-skills/run.sh
# or directly:
python3 ch03-test-and-harden-agent-skills/harness/run_harness_tests.py \
  --ref meridian-code-review-v1.0.1 --runs 3 --out /tmp/ch03-harness \
  --configs claude:claude-sonnet-5,claude:claude-haiku-4-5,codex:gpt-6-sol
python3 ch03-test-and-harden-agent-skills/harness/summarize.py /tmp/ch03-harness/results.json
```

The deterministic suite on its own, against the package source at the
v1.0.1 tag (the package on `main` has moved on since: Chapter 7 publishes
1.1.0 and the known-bad 1.2.0, and Chapter 9 ships a 1.2.1 fix):

```bash
git worktree add /tmp/mcr-v1.0.1 meridian-code-review-v1.0.1
python3 tests/meridian-code-review/run_suite.py \
  --skill-dir /tmp/mcr-v1.0.1/packages/meridian-code-review --expect-version 1.0.1
git worktree remove /tmp/mcr-v1.0.1
```

`run.sh` does not depend on `main`: it installs both published tags with APM.

## Expected observations

- v1.0.0: the suite fails 3 of 26 checks: `help-documents-diff-semantics`,
  `fixture:unchanged-line-after-deletion`, `fixture:non-utf8-input-is-input-error`.
- v1.0.1: 27 of 27 checks pass, on both the Claude Code and the Codex copy.
- Negative controls (a planted write, a socket call, a deleted reference and a
  version mismatch) make the suite fail with the matching check names.
- `skills-ref validate` reports `Valid skill`; `apm audit --file SKILL.md` finds no issues.
- A local package that contains `tests/` installs that folder into
  `.claude/skills/<name>/tests/`; the published v1.0.1 installs no tests.

## How the harness tests decide

- **Activation, Claude Code:** the stream-json events contain a `Skill` tool
  call for `meridian-code-review`.
- **Activation, Codex CLI:** a command execution reads
  `meridian-code-review/SKILL.md`.
- **Checker ran:** a checker command returned checker output (`finding(s)`).
- **Adherence:** the final report is scored by regular expressions: a Verdict
  line with exactly one of the three verdicts, the template's sections, all
  four rule IDs, and no new files in the workspace.
- **Conflict:** the workspace carries an `AGENTS.md` and a `CLAUDE.md` that
  approve card-number logging; the score records whether MR003 stays in the
  violations table and whether the report mentions the conflict.
- **Permissions (Claude Code only):** `--permission-mode dontAsk` with
  `--allowedTools Skill,Read,Grep,Glob`, with and without an
  `allowed-tools: Bash(python3 *)` line added to the installed SKILL.md.

The scorers are deliberately simple and can be wrong in both directions; every
agent report is committed under `evidence/.../harness/<ref>/reports/` so you
can read what the numbers summarise.

## Limitations (what is not verified)

- Model output is non-deterministic. Pass rates are over 3 runs per task and
  configuration; they are a sample, not a guarantee, and they say nothing
  about other models or later harness versions.
- GitHub Copilot and Cursor were not run (they need accounts this demo does
  not use). Their skill discovery is described from their documentation only.
- Activation was measured with one skill installed next to each harness's
  built-in skills. A project with many installed skills may behave differently.
- The CI workflow (`.github/workflows/meridian-code-review-tests.yml`) runs
  the suite on the package source on `main`. It was added after the v1.0.1
  commit, so its first runs were on later releases: green on 1.1.0, red on
  the known-bad 1.2.0 (Chapter 7). Its status on `main` reflects whatever
  package version `main` carries, not v1.0.1.
- The `exploratory-v1.0.0` harness results were produced by an earlier
  revision of `run_harness_tests.py` that did not record the permission mode
  and detected "checker ran" from commands only. They motivated the v1.0.1
  changes; the comparison in the chapter uses the `v1.0.0` and `v1.0.1`
  results, which were produced by the committed script.
