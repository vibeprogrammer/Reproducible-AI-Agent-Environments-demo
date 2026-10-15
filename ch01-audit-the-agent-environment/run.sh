#!/usr/bin/env bash
# Chapter 1 demo: audit Meridian's scattered agent environment.
# Runs in a fresh disposable workspace with an isolated HOME (scripts/lib.sh).
# Network: none required. Writes evidence to evidence/ch01-audit-the-agent-environment/.
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${DEMO_DIR}/../scripts/lib.sh"
demo_begin ch01-audit-the-agent-environment

step "Set up: copy the meridian-checkout fixture and three simulated home directories"
cp -R "${DEMO_DIR}/fixture/meridian-checkout" "$WORK/meridian-checkout"
cp -R "${DEMO_DIR}/fixture/homes" "$WORK/homes"
cp "${DEMO_DIR}/fixture/meridian-rules.json" "$WORK/"
cp "${DEMO_DIR}/audit_inventory.py" "$WORK/"
git -C "$WORK/meridian-checkout" init -q
run_sh 'cd meridian-checkout && find . -path ./.git -prune -o -type f -print | sort'
expect_rc 0
run_sh 'cd homes && find . -type f | sort'
expect_rc 0

step "Inventory: classify, hash and compare every agent-context file"
run python3 audit_inventory.py --project meridian-checkout \
  --home priya=homes/priya --home lena=homes/lena --home anika=homes/anika \
  --rules meridian-rules.json --out-md inventory.md --out-json inventory.json
expect_rc 0 "inventory script"
expect_out "items=14 drift=1 duplicates=0 unpinned_mcp=1 remote_mcp=1 mcp_drift=1 unclassified=0"
expect_file inventory.md
expect_in_file inventory.md 'prompt/command:review\*\*: 4 copies, 3 variants'
expect_in_file inventory.md 'project CLAUDE.md` \| yes \| yes \| CONTRADICTS \| yes'
expect_in_file inventory.md 'project .cursor/commands/review.md` \| CONTRADICTS'
expect_in_file inventory.md 'ledger \| UNPINNED \| `npx @meridian-finance/ledger-mcp`'
expect_in_file inventory.md 'payments-sandbox \| remote'
run cat inventory.md
keep_artifact inventory.md
keep_artifact inventory.json

step "Drift, line by line: the three variants of the review prompt"
run diff -u --label copilot/review.prompt.md --label cursor/review.md \
  meridian-checkout/.github/prompts/review.prompt.md meridian-checkout/.cursor/commands/review.md
expect_rc 1 "Copilot copy and Cursor copy differ"
run diff -u --label copilot/review.prompt.md --label claude/review.md \
  meridian-checkout/.github/prompts/review.prompt.md meridian-checkout/.claude/commands/review.md
expect_rc 1 "Copilot copy and Claude copy differ"
expect_same meridian-checkout/.github/prompts/review.prompt.md homes/priya/.copilot/prompts/review.prompt.md

step "APM v0.33.0: which harnesses does it detect in this project?"
cd "$WORK/meridian-checkout"
run apm --version
expect_out "0\.33\.0"
run apm targets
expect_rc 0
expect_out "claude +active +\.claude/"
expect_out "copilot +active +\.github/copilot-instructions\.md"
expect_out "cursor +active +\.cursor/"
expect_out "codex +inactive"

step "APM v0.33.0: read-only discovery of the project (apm init --discover)"
run apm init --discover
expect_rc 0
expect_out "unsupported: \.github/prompts/review\.prompt\.md"
expect_out "unsupported: \.cursor/mcp\.json"
expect_out "unsupported: CLAUDE\.md"
expect_no_out "vscode/mcp\.json"
expect_out "no manifest changes"
expect_no_file apm.yml
run_sh 'apm init --discover --format json > discover-project.json; echo rc=$?'
expect_out "rc=0"
expect_in_file discover-project.json '"status": "unsupported"'
sed -i "s#${WORK}#<workspace>#g" discover-project.json
keep_artifact discover-project.json

step "APM v0.33.0: read-only discovery of each simulated home (apm init --discover -g)"
run env HOME="$WORK/homes/anika" apm init --discover -g
expect_rc 0
expect_out "supported: \.claude/skills/pr-summary"
expect_out "unsupported: \.claude/CLAUDE\.md"
expect_no_out "claude\.json"
run env HOME="$WORK/homes/lena" apm init --discover -g
expect_rc 0
expect_out "supported: \.agents/skills/sql-migrations"
run env HOME="$WORK/homes/priya" apm init --discover -g
expect_rc 0
expect_out "No missing supported package dependencies"
expect_no_out "copilot/prompts"
expect_no_file ../homes/anika/.apm/apm.yml

step "APM v0.33.0: content scan of untracked primitives (apm audit)"
run apm audit
expect_rc 0
expect_out "6 file\(s\) scanned -- no issues found"
run_sh 'apm audit -f json > audit-project.json; echo rc=$?'
expect_out "rc=0"
expect_in_file audit-project.json '"files_scanned": 6'
expect_in_file audit-project.json '"tracked": false'
expect_not_in_file audit-project.json 'mcp\.json'
keep_artifact audit-project.json

step "APM v0.33.0: provenance lookup needs a lockfile (apm find)"
run apm find .github/prompts/review.prompt.md
expect_out "No lockfile found at apm\.lock\.yaml"

demo_end
