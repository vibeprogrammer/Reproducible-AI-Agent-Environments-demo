# Chapter 1 demo: audit the agent environment

Companion demo for Chapter 1, "Audit the Agent Environment", of
*Reproducible AI Agent Environments* by Maxim Salnikov.

It audits a synthetic copy of Meridian's `meridian-checkout` repository plus
three simulated developer home directories, then checks what APM v0.33.0's
own discovery commands see in the same files.

The public demo repository stands in for Meridian's internal repositories.
Everything in `fixture/` is synthetic: no real secrets, no real MCP servers
(`@meridian-finance/ledger-mcp` and `mcp.payments-sandbox.example` don't
exist), and nothing in the fixture is ever executed.

## Prerequisites

- APM CLI **v0.33.0** on `PATH` (`apm --version`). `scripts/lib.sh` refuses
  to run with any other version.
- Python 3.9+ (standard library only), Git, Bash, `diff`.
- No network access and no credentials are needed.

## Files

| Path | What it is |
| --- | --- |
| `fixture/meridian-checkout/` | Tiny TypeScript service skeleton with scattered agent config: `.github/copilot-instructions.md`, `.github/prompts/review.prompt.md`, `CLAUDE.md`, `.claude/commands/review.md`, `.cursor/rules/checkout.mdc`, `.cursor/commands/review.md`, `.vscode/mcp.json`, `.cursor/mcp.json` |
| `fixture/homes/priya/` | Priya's user-level Copilot files (`~/.copilot/prompts/`, `~/.copilot/instructions/`) |
| `fixture/homes/lena/` | Lena's user-level skill (`~/.agents/skills/sql-migrations/`) |
| `fixture/homes/anika/` | Anika's user-level Claude Code files (`~/.claude/CLAUDE.md`, `~/.claude/skills/pr-summary/`, `~/.claude.json` with one remote MCP server) |
| `fixture/meridian-rules.json` | Meridian's four domain rules as keyword probes |
| `audit_inventory.py` | Stdlib-only inventory script: classify, hash, find drift, check rule coverage, check MCP pinning |
| `run.sh` | The automated demo |

The user-level paths follow where APM v0.33.0's targets matrix and MCP
installation docs say each harness keeps user-scope files.

## Run it

```bash
bash ch01-audit-the-agent-environment/run.sh
```

The script copies the fixture into a fresh temporary workspace with an
isolated `HOME`, then:

1. runs `audit_inventory.py` and writes `inventory.md` / `inventory.json`;
2. diffs the three variants of the review prompt;
3. runs `apm targets`, `apm init --discover` (project), `apm init --discover -g`
   (each simulated home), `apm audit` and `apm find`.

Evidence lands in `evidence/ch01-audit-the-agent-environment/`
(`transcript.log`, `environment.txt`, `result.json`, `artifacts/`).

## Expected observations

- The inventory finds 14 agent-context files across four scopes.
- The review prompt exists as 4 files with 3 different contents. Priya's
  user-level copy is byte-identical to the project's Copilot copy.
- `CLAUDE.md` contradicts the no-PII-logging rule. The Cursor copy of the
  review prompt contradicts the integer-minor-units rule.
- The `ledger` MCP server is unpinned in `.vscode/mcp.json` and pinned to
  `1.4.2` in `.cursor/mcp.json`. Anika's `payments-sandbox` server is remote.
- `apm targets` reports `claude`, `copilot` and `cursor` as active.
- `apm init --discover` lists the loose native files as `unsupported` and
  changes nothing. It doesn't list `.vscode/mcp.json`.
- `apm init --discover -g` finds the two user-level skills as `supported`
  packages, lists Anika's `~/.claude/CLAUDE.md` as `unsupported`, and doesn't
  mention `~/.claude.json` or Priya's `~/.copilot/` files.
- `apm audit` scans the 6 prompt-like files for hidden Unicode (all
  untracked, no findings). The MCP JSON files aren't part of that scan.
- `apm find` can't trace any file, because there is no `apm.lock.yaml` yet
  (it exits non-zero; exit code 2 in the recorded run).

## Limitations (what this demo does NOT verify)

- The keyword probes in `meridian-rules.json` are heuristics. A "yes" means a
  phrase is present, not that an agent obeys it.
- No harness (Copilot, Claude Code, Cursor) was run. The demo doesn't verify
  which of these files each harness actually loads, or in what order.
- Settings stored only in a harness UI or account (for example Cursor's
  global user rules) are invisible to any file-based audit.
- The simulated home directories contain only agent files. A real home holds
  much more state, and a real `~/.claude.json` holds more than `mcpServers`.
