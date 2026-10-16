# Chapter 7 demo: Lock, version, and update safely

Companion demo for Chapter 7 of *Reproducible AI Agent Environments*. It
starts from `meridian-checkout` as Chapter 5 left it (an `apm.yml` that pins
`meridian-code-review#meridian-code-review-v1.0.0`, two MCP servers and the
repository's own primitives under `.apm/`) and walks through what the
lockfile records, what a frozen install checks, how drift is detected, what
happens when a tag moves upstream, and a deliberate update followed by a
rollback.

The public demo repository stands in for Meridian's internal capabilities
repository (`meridian-finance` in the book).

## Prerequisites

- APM **v0.33.0** on `PATH` (`apm --version` must print 0.33.0; the harness
  refuses anything else). The book used the PyPI build: `uv tool install apm-cli==0.33.0`.
- `git`, `python3` (3.9+), `bash`, network access to `github.com`.
- Optional: Claude Code (`claude` on `PATH`) and `ANTHROPIC_API_KEY` (plus
  `ANTHROPIC_BASE_URL` if you use a gateway) for part E. Without them part E
  prints `SKIPPED` and the demo still passes.

## Run

From the repository root:

```bash
bash ch07-lock-version-and-update-safely/run.sh
```

It creates a fresh `mktemp` workspace with an isolated `HOME`, runs every
command shown in the chapter, checks the expected observations and writes
`evidence/ch07-lock-version-and-update-safely/` (`transcript.log`,
`environment.txt`, `result.json`, `artifacts/`).

## Files

| Path | What it is |
|---|---|
| `run.sh` | The demo (parts A to E below). |
| `fixture/meridian-checkout/` | Chapter 5's end state of the service (copied, not shared). |
| `ci/check-agent-environment.sh` | Jon's CI gate: `apm install`, `git diff --exit-code -- apm.yml apm.lock.yaml`, `apm install --frozen`, `apm audit --ci --no-policy`. |
| `ci/agent-environment.yml` | A GitHub Actions workflow wrapping the gate plus a weekly freshness job. **Not executed on GitHub** by this demo. |
| `tools/check_tag_pins.py` | Compares every locked tag's `resolved_commit` with what the tag points at upstream (`git ls-remote`). Stdlib only. |
| `tools/gitserve.py` | A tiny smart-HTTP Git server on 127.0.0.1 (wraps `git http-backend`), used only to simulate a moved tag. |
| `fixtures/capture-without-key.diff` | A capture call without an idempotency key (MR002 in v1.1.0, missed by v1.0.x). |
| `behaviour/two_runs.py` | Part E: runs the same installed skill twice in Claude Code and compares the outputs. |

## What it shows (expected observations)

**A. Lockfile and frozen installs.** `apm install` writes `apm.lock.yaml`
(`lockfile_version: '1'`, `resolved_ref`, the full `resolved_commit`,
`content_hash`, per-file `deployed_file_hashes`, `mcp_configs`,
`local_deployed_files`, `deployments`). A second install leaves it
byte-identical. On a fresh clone with an empty `HOME`, a bare
`apm install --frozen` **fails** with "package manifest not found" (APM
0.33.0, cold `apm_modules/`, project declares MCP servers); Jon's gate
(install, require no lockfile change, `--frozen`, `apm audit --ci`) passes and
the generated files are byte-identical to Priya's. `--frozen` refuses a
manifest whose ref differs from the lockfile, and a missing lockfile (exit 1).

**B. Drift.** A hand edit to `.claude/skills/meridian-code-review/SKILL.md`:
`apm audit` reports it but **exits 0**; `apm audit --ci --no-policy` exits 1
(`content-integrity` hash drift and `drift`); `apm install --frozen` restores
the locked bytes.

**C. A tag that moves.** A third-party skill on a local Git server is pinned
to tag `v1.0.0`; the author force-moves the tag. `apm outdated` still says
"All dependencies are up-to-date"; `check_tag_pins.py` reports `MOVED`;
installs with the lockfile (normal, and frozen from a cold cache) keep the
locked commit; an install of the same manifest without a lockfile gets the new
content. When upstream history is rewritten so the locked commit no longer
exists, `apm install --frozen` fails (exit 1) and deploys nothing.

**D. Update and roll back.** `apm outdated` lists `meridian-code-review-v1.2.0`
as latest; `apm update --dry-run` does not move exact tag pins (a `^1.0.0`
range would move to v1.2.0). Priya updates to v1.1.0 with
`apm install <pkg>#meridian-code-review-v1.1.0`; the Chapter 3 suite
(`tests/meridian-code-review/run_suite.py`) passes on the installed copy and the
new capture rule fires. The update to v1.2.0 passes Jon's gate but the suite
fails (`fixture:bad-diff-six-findings`: 5 findings, `shippingFee = 4.99` no
longer flagged). `git revert` of the update commit restores `apm.yml` and a
lockfile byte-identical to v1.1.0's; `apm install --frozen` redeploys files
whose hashes match the v1.1.0 fingerprint; the suite passes again; a fresh CI
clone reproduces v1.1.0 exactly.

**E. Behaviour (optional).** Two Claude Code runs of the same installed skill
on the same diff: both invoke the skill, both request changes and mention
MR001 to MR004, and the texts differ.

## Limitations: what is not verified

- `ci/agent-environment.yml` was not run on GitHub Actions; its steps were run
  locally by `run.sh`.
- The moved-tag simulation uses a local HTTP server and an `http://`
  dependency (`allow_insecure: true`, `--allow-insecure`). `apm update` has
  no `--allow-insecure` option in 0.33.0, so update behaviour against a moved
  tag was not exercised; behaviour against GitHub-hosted moved tags was not
  tested (the book never moves a published tag).
- The cold-checkout `--frozen` failure is observed behaviour of APM 0.33.0,
  not documented behaviour; a later APM may change it.
- Part E depends on a model and is not deterministic; two runs prove nothing
  statistically. Copilot, Cursor and Codex were not run in this demo.
- The demo needs `github.com` and the `meridian-code-review-v1.0.0`,
  `-v1.1.0` and `-v1.2.0` tags to stay where they are.
