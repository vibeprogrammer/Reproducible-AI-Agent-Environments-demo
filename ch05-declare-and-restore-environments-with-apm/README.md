# Chapter 5 demo: Declare and Restore Environments with APM

Companion demo for Chapter 5 of *Reproducible AI Agent Environments*.
Priya declares the agent environment of Meridian's `meridian-checkout`
service in `apm.yml`, installs it for GitHub Copilot, Claude Code and Cursor,
and commits the declaration. Anika then clones the repository on a "fresh
laptop" (a second, empty `HOME`), restores the environment with one
`apm install`, and verifies it. Two side labs record what Meridian decided
**not** to put in its manifest, and why.

In the book, this public repository stands in for Meridian's internal
`meridian-finance` repositories, and the fixture's Git repository is created
inside the disposable workspace.

## Prerequisites

- Linux or macOS with `bash`, `git`, `sha256sum` and Python 3.
- APM **0.33.0** on `PATH` (`apm --version`). The harness refuses any other
  version. The verification run used the PyPI build (`apm-cli==0.33.0`),
  because the official Linux release binary needs glibc 2.38 or newer and
  the test machine (Debian 12) has 2.36.
- Network access to `github.com` (the skill package, and the plugin in side
  lab B) and to the MCP registry that APM 0.33.0 queries by default (side
  lab A only). No tokens or credentials are used.

## Files

| Path | What it is |
|------|------------|
| `run.sh` | The automated demo (sources `../scripts/lib.sh`) |
| `fixture/meridian-checkout/apm.yml` | Meridian's manifest: four targets, the pinned skill, two MCP servers |
| `fixture/meridian-checkout/.apm/instructions/money-handling.instructions.md` | Repo-owned instruction (`applyTo: "src/**/*.ts"`) |
| `fixture/meridian-checkout/.apm/prompts/review-checkout-change.prompt.md` | Repo-owned prompt with one input |
| `fixture/meridian-checkout/.apm/agents/payments-reviewer.agent.md` | Repo-owned agent |
| `fixture/meridian-checkout/gitignore.txt` | Becomes `.gitignore`: generated files are not committed |
| `fixture/meridian-checkout/src/`, `package.json`, `tsconfig.json` | A tiny synthetic TypeScript service |
| `expected/generated-files.txt` | The 25 files `apm install` must generate for Meridian's targets |

## Run it

```bash
bash ch05-declare-and-restore-environments-with-apm/run.sh
```

Evidence lands in `evidence/ch05-declare-and-restore-environments-with-apm/`
(`transcript.log`, `environment.txt`, `result.json`, `artifacts/`).

## What it checks (expected observations)

1. `apm --version` reports 0.33.0. `apm init -y` in an empty repository
   writes an `apm.yml` with commented-out `targets`, empty `apm` and `mcp`
   lists, and `includes: auto`.
2. **Priya's install.** The manifest pins `targets: [copilot, vscode,
   claude, cursor]`. `apm targets` reports all targets inactive before the
   first install (it reports on-disk detection signals). `apm install` then
   uses the pinned list (`Targets: claude, copilot, cursor (source: apm.yml)`
   for file primitives; `vscode` is folded into `copilot` there but still
   gets its own MCP config), resolves the skill tag to commit `d77ad92`, and
   configures two self-defined MCP servers: `ledger` (stdio,
   `npx -y @meridian-finance/ledger-mcp@1.4.2`, key referenced as
   `${LEDGER_API_KEY}`) and `microsoft-learn` (remote, no credentials).
   Priya's shell has a dummy `LEDGER_API_KEY` set.
3. **What lands where.** Exactly the 25 files in
   `expected/generated-files.txt`: the skill folder under `.claude/skills/`
   and under `.agents/skills/` (shared by Copilot and Cursor); the
   instruction as `.github/instructions/*.instructions.md` (`applyTo`),
   `.claude/rules/*.md` (`paths:`) and `.cursor/rules/*.mdc` (`globs:`); the
   prompt as a Copilot prompt file and as Claude and Cursor commands; the
   agent once per target; and the MCP servers in `.github/mcp.json`
   (Copilot CLI), `.vscode/mcp.json`, `.mcp.json` (Claude Code) and
   `.cursor/mcp.json`. The key is written as a reference in the Copilot,
   VS Code and Cursor files (`${LEDGER_API_KEY}` or `${env:LEDGER_API_KEY}`),
   **but `.mcp.json` receives the dummy value itself** because the variable
   was set at install time. The value appears in no other file, including
   the lockfile.
4. **Lockfile.** `apm.lock.yaml` records `apm_version: 0.33.0`, the skill's
   `resolved_ref` and `resolved_commit`, and both MCP servers.
5. **Commit.** Only the declaration is committed: `apm.yml`,
   `apm.lock.yaml`, `.apm/` and `.gitignore` (plus the service code).
6. **Anika's restore.** From an empty `HOME` and a fresh clone (no
   `LEDGER_API_KEY` set), `apm install` produces the same 25 files. All of
   them except `.mcp.json` have the same SHA-256 digests as on Priya's
   machine; `.mcp.json` differs in exactly one line (the reference instead
   of the value). `git status` stays clean (the lockfile is unchanged), and
   the install warns that Copilot CLI needs `LEDGER_API_KEY` at runtime.
7. **Verification.** `apm targets` shows the three targets active;
   `apm deps tree` shows the skill at 1.0.0; `apm audit` finds no drift and
   no content issues; `apm audit --ci` passes; `apm install --frozen` and
   `apm doctor` exit 0.
8. **Drift.** After a hand edit to `.claude/rules/money-handling.md`, plain
   `apm audit` prints `Drift detected: 1 file(s)` but exits 0;
   `apm audit --ci` exits 1. `apm install` restores the original bytes.
9. **Narrowing the target.** A one-off `apm install --target claude`
   removes both MCP servers from the Copilot CLI, VS Code and Cursor configs
   (`Removed stale MCP server ...`). A plain `apm install` puts them back and
   the digests match again.
10. **User scope.** `apm install -g ... --target claude` writes
   `~/.apm/apm.yml`, `~/.apm/apm.lock.yaml` and
   `~/.claude/skills/meridian-code-review/`, and touches nothing in the
   current directory.
11. **Side lab A.** A registry MCP server (`io.github.upstash/context7`)
    makes `apm install` ask for `CONTEXT7_API_KEY`; with no terminal input
    the install exits 1 and writes no MCP config.
12. **Side lab B.** Adding the public Agent Plugin
    `github/awesome-copilot/plugins/context-engineering` (pinned to a commit)
    to Meridian's manifest: the install succeeds and registers the plugin in
    `.github/copilot/settings.local.json`, but the fetched plugin directory
    holds only `plugin.json` and `README.md`, not the agent and skill paths
    its manifest lists. `apm audit` then reports that its drift check could
    not run, and `apm install --frozen` exits 1 (`out of sync`).

## Observed behaviour worth knowing (APM 0.33.0)

- `apm deps list` exits 1 with `Invalid local package path ''` once the
  project has local `.apm/` content (step 6d asserts this). `apm deps tree`
  works. A project without local content lists its dependencies normally.
- Plain `apm audit` reports drift without failing; use `apm audit --ci` as
  a gate.
- For the Claude Code target, a `${VAR}` in a self-defined server's `env` is
  resolved from the installing shell when the variable is set, and the value
  is written into `.mcp.json`. With the variable unset, the reference is
  written. Keep `.mcp.json` out of Git (the fixture's `.gitignore` does).
- `apm install --target X` rewrites the MCP configs of targets outside `X`.

## Limitations (what this demo does NOT verify)

- Whether Copilot, Claude Code or Cursor actually load the generated files,
  start the MCP server, or invoke the skill, prompt or agent. The demo checks
  APM's file deployment only.
- Whether `https://learn.microsoft.com/api/mcp` answers MCP requests. APM
  writes the configuration; it does not start or contact the server.
- The `ledger` server is synthetic: `@meridian-finance/ledger-mcp` is not a
  published npm package, so it cannot start. Only its configuration is
  verified.
- Whether the Copilot plugin registration in side lab B results in any
  usable agent or skill in Copilot.
- Windows and macOS installs, and the official release binaries (the run used
  the PyPI build of the same version).
