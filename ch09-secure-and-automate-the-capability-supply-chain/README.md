# Chapter 9 demo: secure and automate the capability supply chain

Companion to Chapter 9 of *Reproducible AI Agent Environments*
([manuscript](https://github.com/vibeprogrammer/Reproducible-AI-Agent-Environments/blob/main/manuscript/09-secure-and-automate-the-capability-supply-chain.md)).
Jon, Meridian's platform/security engineer, puts a gate in front of every
change to the agent supply chain. This folder shows what APM v0.33.0's
install-time checks and `apm audit` catch, what they do not, and the extra
checks that close part of the gap. The workflow
[`.github/workflows/ch09-supply-chain-gate.yml`](../.github/workflows/ch09-supply-chain-gate.yml)
runs the same gate on GitHub Actions.

The public demo repository stands in for Meridian's internal repositories
(`meridian-finance/meridian-checkout` and the shared packages repository).

## Prerequisites

- APM CLI **0.33.0** on `PATH` (`scripts/lib.sh` refuses any other version)
- Python 3.9+, Git, Bash
- Network access to public GitHub (the `meridian-code-review` tags)

## Files

| Path | What it is |
|---|---|
| `run.sh` | The whole demo, 12 steps, run in a fresh workspace with an isolated `HOME` |
| `make_fixtures.py` | Generates the synthetic threat fixtures at run time (so this repository contains no invisible characters) |
| `gate/check_supply_chain.py` | Jon's tripwire: credentials in manifests, unpinned git dependencies, gate-bypass flags in CI files |
| `fixture/meridian-checkout/` | Chapter 5's `meridian-checkout`, pinned to `meridian-code-review-v1.1.0`, with its committed `apm.lock.yaml` |
| `fixture/bad-ci-step.sh` | A CI step that switches a gate off; the guard must reject it |
| `../tests/meridian-code-review/run_suite.py` | Chapter 3's regression suite, reused as a gate |

## Run it

```bash
bash ch09-secure-and-automate-the-capability-supply-chain/run.sh
```

Evidence lands in `evidence/ch09-secure-and-automate-the-capability-supply-chain/`
(`transcript.log`, `environment.txt`, `result.json`, `artifacts/`).

## Expected observations (APM 0.33.0)

1. **Baseline.** `apm install --frozen` on a cold checkout exits 1 with
   `package manifest not found`; `apm install` from the committed lockfile
   leaves `apm.yml` and `apm.lock.yaml` unchanged (`git diff --exit-code`);
   `apm audit --ci` passes all 10 checks and writes SARIF 2.1.0; Chapter 3's
   suite passes on the installed skill; the guard finds 0 problems.
2. **Fixtures** are generated: tag characters, a bidi override, a
   zero-width space, a plain-text injection, a tampered copy of the published
   v1.1.0 skill, and a two-level package chain that carries an MCP server.
3. **Tag characters:** `apm install` exits 1 (`Blocked: ...`), nothing of the
   package is deployed, no lockfile is written; `apm audit --file` exits 1.
4. **Bidi override:** blocked the same way.
5. **Zero-width space:** deployed; `apm audit` exits 2 (warning only).
6. **Plain-text injection:** installs; `apm audit` exits 0. Not caught.
7. **Tampered script:** the `diff` shows the injected `socket` code; APM
   installs it (exit 0) and `apm audit` exits 0; Chapter 3's suite exits 1
   on `no-write-network-or-subprocess-events` (`socket.connect`). The suite
   does not flag the read-only peek at `~/.ssh` (it records writes, network
   and subprocess events only).
8. **Transitive MCP:** install exits 0 with a warning, `.mcp.json` is not
   written, but the package's instruction text still deploys;
   `apm audit --ci` exits 1 (`ledger-lookup: in manifest but not in
   lockfile`). Re-declaring the server in the top-level `apm.yml` writes
   `.mcp.json` and `apm audit --ci` passes.
9. **Observed gap:** with `executables: {}` (gate on), a plain install parks
   the MCP server; `apm install --trust-transitive-mcp` then writes it to
   `.mcp.json` although the lockfile records `exec_status:
   gated_pending_approval`, and `apm audit --ci` passes. The guard rejects
   the flag in CI files.
10. **Credentials:** APM installs a git URL with userinfo; the lockfile does
    not contain the secret, `apm.yml` still does; the guard exits 1.
11. **Order matters:** a hand-edited deployed `SKILL.md` fails
    `apm audit --ci` (`hash-drift`); `apm install --frozen` silently restores
    it, after which `apm audit --ci` passes.
12. **PR validation and rollback:** bumping to `meridian-code-review-v1.2.0`
    installs, and the suite fails (`fixture:bad-diff-six-findings`).
    `git revert` + `apm install --frozen` deploys v1.1.0 again but leaves a
    stale `version: 1.2.0` label in the lockfile; a normal `apm install`
    repairs it and the lockfile is byte-identical to the baseline.

## Limitations and what is NOT verified

- Everything ran on Linux x86_64 with the PyPI build of APM 0.33.0. The
  GitHub Actions workflow uses the official release binary through
  `microsoft/apm-action`; its run results are recorded in the chapter.
- The fixtures are synthetic and harmless. They show detection behaviour;
  they say nothing about how a real model would act on the injected text.
- No harness (Copilot, Claude Code, Cursor, Codex) was asked to load the
  hostile fixtures. Runtime behaviour of an injected skill is unverified.
- Repository protections (branch and tag rulesets, CODEOWNERS, token scopes)
  are described in the chapter from GitHub's documentation; this demo does
  not change the repository's settings.
- `gate/check_supply_chain.py` is a tripwire for honest mistakes. Someone
  determined to bypass it can.
