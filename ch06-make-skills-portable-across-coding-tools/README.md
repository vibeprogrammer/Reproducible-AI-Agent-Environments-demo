# Chapter 6 demo: make skills portable across coding tools

Companion to Chapter 6 of *Reproducible AI Agent Environments*. It installs
one Meridian package set into every target APM v0.33.0 supports, records
where each primitive lands, builds a compatibility matrix from those runs,
and (when credentials are available) asks two real harnesses, Claude Code
and Codex CLI, what they actually discovered.

## Prerequisites

- APM **v0.33.0** on `PATH` (`apm --version`); `scripts/lib.sh` refuses any
  other version.
- Git, Python 3.9+, network access to github.com (the skill is a real Git
  dependency).
- Optional, for the runtime checks:
  - Claude Code 2.1.301 (`claude`) and `ANTHROPIC_API_KEY` (optional
    `ANTHROPIC_BASE_URL`, model via `CLAUDE_MODEL`, default `claude-sonnet-5`);
  - Codex CLI 0.163.0 (`codex`) and `OPENAI_API_KEY` (optional
    `OPENAI_BASE_URL`, which makes `harness_check.py` write a custom-provider
    `config.toml` into a throwaway `CODEX_HOME`; model via `CODEX_MODEL`,
    default `gpt-6-sol`).
  Without them those checks are reported as `skipped (no credentials)` and
  the structural part of the demo still runs and passes.
  `HARNESS_RUNS` sets the runs per check (default 3).

## Files

- `fixture/meridian-checkout/` — Meridian's service as Chapter 5 left it,
  with `apm.yml` declaring:
  - `meridian-code-review` at tag `meridian-code-review-v1.0.0` (Chapter 2;
    the newest published tag when this demo was recorded);
  - the project's own primitives under `.apm/`: one instructions file
    (`applyTo: src/**/*.ts`), one prompt, one agent and one hook
    (`.apm/hooks/money-rules-reminder.json` plus a read-only script);
  - the `ledger` MCP server (self-defined, stdio, pinned, key referenced
    as `${LEDGER_API_KEY}` and never written);
  - two tool-specific notes packages (see below).
  `PORTABILITY.md` is Meridian's portability checklist (Chapter 6).
- `fixture/agent-packages/meridian-claude-notes/` — restricted to Claude
  Code in its own `apm.yml` (`target: claude`).
- `fixture/agent-packages/meridian-cursor-notes/` — no restriction of its
  own; the consumer narrows it with object-form `targets: [cursor]`.
  (Both are local sibling folders here; Meridian keeps them in its shared
  capabilities repository, for which this public repo stands in.)
- `run.sh` — the whole demo.
- `matrix_tool.py` — snapshots, diffs, output cleaning and the matrix
  generator (standard library only).
- `harness_check.py` — runs one check N times in Claude Code or Codex CLI
  with a fresh, empty `HOME`/`CODEX_HOME` per run.

## What run.sh does

1. Target detection: removes `targets:` and shows `apm targets` with no
   markers (and `apm install` exiting 2), then with `.cursor/` and
   `CLAUDE.md`; then restores `targets:`.
2. One target at a time: for each of `copilot vscode intellij claude cursor
   codex gemini antigravity opencode windsurf kiro grok-build hermes
   agent-skills`, and the experimental `grok-cloud openclaw` (flag enabled
   in that run's own HOME), a fresh copy of the fixture with its own HOME
   and `apm install --target <t>`. Every new or changed file (project and
   HOME) is recorded. When APM asks for `apm compile`, it runs
   `apm compile --target <t>` and records that too.
3. Isolation checks for the two notes packages.
4. Together: Meridian's declared targets from `apm.yml`; all stable targets
   in one comma list; and `--target all`. Then `apm compile --target codex`
   in the Meridian workspace (see "Observations").
5. Runtime checks (optional) in Claude Code and Codex CLI.
6. `matrix_tool.py matrix` turns the recorded runs into
   `evidence/ch06-make-skills-portable-across-coding-tools/compatibility-matrix.md`
   (and `.json`).

```bash
bash ch06-make-skills-portable-across-coding-tools/run.sh
```

## Expected observations (APM v0.33.0)

- `apm targets` reports filesystem detection only. With `targets:` in
  `apm.yml` it still lists every target as `inactive` unless a marker
  exists, although `apm install` reports `Targets: claude, copilot, cursor
  (source: apm.yml)`.
- With nothing to detect and no `targets:`, `apm install` exits 2
  (`No harness detected`) and writes no lockfile.
- The skill lands in `.agents/skills/` for every target except `claude`
  (`.claude/skills/`), `kiro` (`.kiro/skills/`) and `grok-build` /
  `grok-cloud` (`.grok/skills/`).
- Unsupported primitives are skipped without a message (for example no
  prompt for codex, kiro, antigravity or hermes; no hook for opencode or
  grok-build; no agent for gemini, windsurf, antigravity or hermes).
- Targets without an MCP client (`grok-build`, `agent-skills`, `grok-cloud`,
  `openclaw`) make the install **exit 1** because the set declares an MCP
  server, after the skill and other files were already written.
- `codex`, `gemini`, `opencode`, `hermes` and `grok-build` print
  `Run 'apm compile' to update AGENTS.md`; their instructions reach the
  harness only through `apm compile`.
- The notes packages reach only their tool on install. `apm compile
  --target codex` nevertheless folds both into `AGENTS.md`.

## What is NOT verified

- Runtime behaviour of every harness except Claude Code 2.1.301 and Codex
  CLI 0.163.0, and of those two only for the checks listed in the matrix
  (skill discovery and use, always-on and file-scoped instructions). Copilot,
  Cursor, Gemini CLI, Antigravity, OpenCode, Windsurf, Kiro, Grok, Hermes,
  OpenClaw and JetBrains need accounts, GUIs or products we did not run.
- Hooks, agents, commands and MCP servers at runtime: Claude Code's start-up
  event lists the agent, the command and the `ledger` server (with status
  `failed`, because `@meridian-finance/ledger-mcp` is synthetic), but no
  hook was triggered and no MCP tool was called. Codex's agent, hook and MCP
  config were not exercised.
- Model answers are non-deterministic; results are pass counts over the runs
  recorded in `evidence/.../artifacts/harness/`.
- `copilot-app` and `copilot-cowork` (experimental) were not run: they need
  the Copilot desktop app and Microsoft 365.
