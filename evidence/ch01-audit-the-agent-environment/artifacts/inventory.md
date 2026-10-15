# Agent environment inventory

Scanned: project, user:priya, user:lena, user:anika

| Scope | Path | Type | Harness | SHA-256 (12) |
| --- | --- | --- | --- | --- |
| project | `CLAUDE.md` | instructions | claude | `e10b57b70170` |
| project | `.claude/commands/review.md` | command | claude | `74adae27fc23` |
| project | `.cursor/mcp.json` | mcp | cursor | `6161b98adcaa` |
| project | `.cursor/commands/review.md` | command | cursor | `981594c4ce72` |
| project | `.cursor/rules/checkout.mdc` | instructions | cursor | `f78762647c6e` |
| project | `.github/copilot-instructions.md` | instructions | copilot | `a4969d8e32ee` |
| project | `.github/prompts/review.prompt.md` | prompt | copilot | `7ab1c6f56970` |
| project | `.vscode/mcp.json` | mcp | copilot (VS Code) | `9880b6d18c77` |
| user:priya | `.copilot/instructions/typescript-style.instructions.md` | instructions | copilot | `d9a37173db62` |
| user:priya | `.copilot/prompts/review.prompt.md` | prompt | copilot | `7ab1c6f56970` |
| user:lena | `.agents/skills/sql-migrations/SKILL.md` | skill | shared (.agents) | `7d80cbdd33a0` |
| user:anika | `.claude.json` | mcp | claude | `7980481dd64a` |
| user:anika | `.claude/CLAUDE.md` | instructions | claude | `624052f7f233` |
| user:anika | `.claude/skills/pr-summary/SKILL.md` | skill | claude | `e6b71be3291c` |

## Drift (same name, different content)

- **prompt/command:review**: 4 copies, 3 variants
  - `74adae27fc23`: project .claude/commands/review.md
  - `7ab1c6f56970`: project .github/prompts/review.prompt.md; user:priya .copilot/prompts/review.prompt.md
  - `981594c4ce72`: project .cursor/commands/review.md

## Duplicates (same name, identical content)

None found.

## Team-rule coverage (keyword probes, heuristic)

| File | minor-units | idempotency | no-pii-logs | iso-4217 |
| --- | --- | --- | --- | --- |
| `project CLAUDE.md` | yes | yes | CONTRADICTS | yes |
| `project .claude/commands/review.md` | yes | - | yes | - |
| `project .cursor/commands/review.md` | CONTRADICTS | yes | - | yes |
| `project .cursor/rules/checkout.mdc` | yes | - | yes | yes |
| `project .github/copilot-instructions.md` | yes | yes | yes | yes |
| `project .github/prompts/review.prompt.md` | yes | yes | yes | yes |
| `user:priya .copilot/instructions/typescript-style.instructions.md` | - | - | - | - |
| `user:priya .copilot/prompts/review.prompt.md` | yes | yes | yes | yes |
| `user:anika .claude/CLAUDE.md` | - | - | - | - |

## MCP servers

| File | Server | Status | Detail |
| --- | --- | --- | --- |
| `project .cursor/mcp.json` | ledger | pinned | `npx @meridian-finance/ledger-mcp@1.4.2` |
| `project .vscode/mcp.json` | ledger | UNPINNED | `npx @meridian-finance/ledger-mcp` |
| `user:anika .claude.json` | payments-sandbox | remote | `https://mcp.payments-sandbox.example/mcp` |

Servers configured differently across files: ledger

## Unclassified files under harness directories

None.

## Not visible to this audit

- Settings stored only in a harness UI or cloud account.
- Model versions, harness versions and runtime permissions.
- What a remote MCP server does when called.
- Secrets referenced by placeholders (values are never read).
