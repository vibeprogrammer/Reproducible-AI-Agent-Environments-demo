#!/usr/bin/env bash
# Chapter 5: Declare and Restore Environments with APM
# Priya declares meridian-checkout's agent environment in apm.yml, installs
# it for Copilot, Claude Code and Cursor, and commits the manifest, the
# lockfile and the repo's own primitives. Anika then clones the repository
# on a "fresh laptop" (a second, empty HOME), restores the environment with
# one command and verifies it. Two side labs record what did NOT go into
# Meridian's manifest and why: a registry MCP server that asks for a
# credential, and a third-party Agent Plugin.
source "$(dirname "$0")/../scripts/lib.sh"
demo_begin ch05-declare-and-restore-environments-with-apm

DEMO_DIR="$REPO_ROOT/ch05-declare-and-restore-environments-with-apm"
FIXTURE="$DEMO_DIR/fixture/meridian-checkout"
SKILL_COMMIT="d77ad927023f2b227bd130c2f436866cc07b2e9e"
PLUGIN_REF="github/awesome-copilot/plugins/context-engineering#bebb02d4c3c845b9c4cef398568a1084e4129e57"
export APM_PROGRESS=never   # documented env var: plain logs, no live progress UI

# Save the last command's output as evidence, with workspace paths normalized.
keep_out() { mkdir -p "$EVIDENCE/artifacts"; _norm < "$LAST_OUT" > "$EVIDENCE/artifacts/$1"; }

# Deployed files that `apm install` generates for the three targets.
generated() {
  find .agents .claude .cursor .github .vscode .mcp.json -type f 2>/dev/null | LC_ALL=C sort
}
# One SHA-256 line per generated file, for comparing two machines.
# .mcp.json is compared separately (see step 6a): its content depends on
# the shell environment at install time.
fingerprint() { generated | grep -vx '\.mcp\.json' | xargs sha256sum; }

# ---------------------------------------------------------------------------
step "1. The pinned CLI"
run apm --version
expect_rc 0
expect_out 'version 0\.33\.0'

# ---------------------------------------------------------------------------
step "2. What apm init scaffolds (empty scratch project)"
mkdir scaffold && cd scaffold && git init -q
run apm init -y
expect_rc 0
expect_file apm.yml
run cat apm.yml
expect_out '^includes: auto$'
expect_out '^# targets:$'
keep_artifact apm.yml apm-init-scaffold.yml
cd "$WORK"

# ---------------------------------------------------------------------------
step "3. Priya: meridian-checkout with its own primitives and apm.yml"
export HOME="$WORK/priya-home"; mkdir -p "$HOME"
git config --global init.defaultBranch main
git config --global advice.detachedHead false
mkdir -p priya && cp -R "$FIXTURE" priya/meridian-checkout
cd priya/meridian-checkout
mv gitignore.txt .gitignore
git init -q
run_sh 'find . -path ./.git -prune -o -type f -print | LC_ALL=C sort'
expect_out '\./\.apm/agents/payments-reviewer\.agent\.md'
expect_out '\./\.apm/instructions/money-handling\.instructions\.md'
expect_out '\./\.apm/prompts/review-checkout-change\.prompt\.md'
run cat apm.yml
expect_out 'meridian-code-review#meridian-code-review-v1\.0\.0'
keep_artifact apm.yml apm.yml

step "3a. apm targets before the first install (targets are pinned in apm.yml)"
run apm targets
expect_rc 0
expect_out '^ +claude +inactive'
keep_out targets-before-install.txt

# ---------------------------------------------------------------------------
step "4. Priya: apm install (with a dummy LEDGER_API_KEY in her shell)"
export LEDGER_API_KEY="demo-value-not-a-real-key"
run apm install
expect_rc 0
expect_out 'Targets: claude, copilot, cursor +\(source: apm\.yml\)'
expect_out 'meridian-code-review-v1\.0\.0 @d77ad927'
expect_out 'microsoft-learn'
expect_out 'Installed 2 APM dependencies and 2 MCP servers'
keep_out priya-install.txt

step "4a. What landed where"
run_sh 'find .agents .claude .cursor .github .vscode .mcp.json -type f | LC_ALL=C sort'
expect_rc 0
generated > ../generated-files.txt
keep_artifact ../generated-files.txt generated-files.txt
cp "$DEMO_DIR/expected/generated-files.txt" ../expected-generated-files.txt
expect_same ../generated-files.txt ../expected-generated-files.txt
# Skill: whole folder for Claude; .agents/skills/ is shared by Copilot and Cursor
expect_file .claude/skills/meridian-code-review/scripts/check_money_rules.py
expect_file .agents/skills/meridian-code-review/SKILL.md
expect_no_file .cursor/skills
# Instruction: one source, three native formats
expect_in_file .github/instructions/money-handling.instructions.md '^applyTo: "src/\*\*/\*\.ts"'
expect_in_file .claude/rules/money-handling.md '^paths:'
expect_in_file .cursor/rules/money-handling.mdc '^globs: '
run_sh 'head -6 .claude/rules/money-handling.md; echo ---; head -6 .cursor/rules/money-handling.mdc'
# Prompt: a Copilot prompt file, a Claude/Cursor command
expect_file .github/prompts/review-checkout-change.prompt.md
expect_file .claude/commands/review-checkout-change.md
expect_file .cursor/commands/review-checkout-change.md
# Agent: one per target
expect_file .github/agents/payments-reviewer.agent.md
expect_file .claude/agents/payments-reviewer.md
expect_file .cursor/agents/payments-reviewer.md
# MCP: one config file per target, no secrets in any of them
run_sh 'for f in .github/mcp.json .vscode/mcp.json .mcp.json .cursor/mcp.json; do echo "== $f"; cat "$f"; echo; done'
for f in .github/mcp.json .vscode/mcp.json .mcp.json .cursor/mcp.json; do
  expect_in_file "$f" 'https://learn\.microsoft\.com/api/mcp'
  expect_in_file "$f" '@meridian-finance/ledger-mcp@1\.4\.2'
done
# The key is written as a reference in each tool's own syntax, never as a value
expect_in_file .github/mcp.json '"LEDGER_API_KEY": "\$\{LEDGER_API_KEY\}"'
expect_in_file .vscode/mcp.json '"LEDGER_API_KEY": "\$\{env:LEDGER_API_KEY\}"'
expect_in_file .cursor/mcp.json '"LEDGER_API_KEY": "\$\{env:LEDGER_API_KEY\}"'
# Observed in 0.33.0: with the variable set, the Claude Code config gets the value
run_sh 'grep -rl "demo-value-not-a-real-key" .agents .claude .cursor .github .vscode .mcp.json apm.lock.yaml apm.yml'
expect_out '^\.mcp\.json$'
expect_no_out 'apm\.lock\.yaml|apm\.yml|\.github|\.vscode|\.cursor'
expect_in_file .mcp.json '"LEDGER_API_KEY": "demo-value-not-a-real-key"'
keep_artifact .vscode/mcp.json vscode-mcp.json
keep_artifact .github/mcp.json copilot-mcp.json
keep_artifact .mcp.json claude-mcp.json
keep_artifact .cursor/mcp.json cursor-mcp.json

step "4b. The lockfile (introduced here; Chapter 7 covers it in depth)"
expect_file apm.lock.yaml
expect_in_file apm.lock.yaml '^apm_version: 0\.33\.0$'
expect_in_file apm.lock.yaml "resolved_commit: ${SKILL_COMMIT}"
expect_in_file apm.lock.yaml 'resolved_ref: meridian-code-review-v1\.0\.0'
expect_in_file apm.lock.yaml 'name: microsoft-learn'
run_sh 'sed -n "1,16p" apm.lock.yaml'
keep_artifact apm.lock.yaml apm.lock.yaml
expect_in_file .gitignore '^apm_modules/$'

step "4c. Priya commits the declaration, not the generated files"
run_sh 'git add -A && git status --porcelain'
expect_no_out '\.claude/|\.cursor/|\.mcp\.json|\.agents/'
run_sh 'git commit -q -m "Declare the agent environment with APM" && git ls-files'
expect_out '^apm\.yml$'
expect_out '^apm\.lock\.yaml$'
expect_out '^\.apm/instructions/money-handling\.instructions\.md$'
expect_no_out '^\.claude/'
fingerprint > ../../priya.sha256
keep_artifact ../../priya.sha256 priya-generated.sha256
unset LEDGER_API_KEY
cd "$WORK"

# ---------------------------------------------------------------------------
step "5. Anika: a fresh laptop (new, empty HOME) clones the repository"
export HOME="$WORK/anika-home"; mkdir -p "$HOME"
git config --global init.defaultBranch main
git config --global advice.detachedHead false
run_sh 'ls -A "$HOME" | grep -v "^\.gitconfig$" | wc -l'
expect_out '^0$'
mkdir anika && git clone -q "$WORK/priya/meridian-checkout" anika/meridian-checkout
cd anika/meridian-checkout
run_sh 'ls -A'
expect_no_file .claude
expect_no_file .agents
expect_no_file apm_modules
expect_file apm.lock.yaml

step "5a. Anika: apm install"
run apm install
expect_rc 0
expect_out 'Targets: claude, copilot, cursor +\(source: apm\.yml\)'
expect_out '@d77ad927'
expect_out 'not currently set: LEDGER_API_KEY'
keep_out anika-install.txt

# ---------------------------------------------------------------------------
step "6. Anika: verify the restored environment"
step "6a. Same files, same bytes as Priya's machine"
fingerprint > ../../anika.sha256
run_sh 'wc -l < ../../anika.sha256'
expect_same ../../priya.sha256 ../../anika.sha256
run_sh 'git status --porcelain; echo "status-lines: $(git status --porcelain | wc -l)"'
expect_out '^status-lines: 0$'
step "6a2. The one file that differs: .mcp.json (Anika has no LEDGER_API_KEY set)"
expect_in_file .mcp.json '"LEDGER_API_KEY": "\$\{LEDGER_API_KEY\}"'
run_sh 'diff ../../priya/meridian-checkout/.mcp.json .mcp.json'
expect_rc 1

step "6b. apm targets"
run apm targets
expect_rc 0
expect_out '^ +claude +active'
expect_out '^ +copilot +active'
expect_out '^ +cursor +active'

step "6c. apm deps tree"
run apm deps tree
expect_rc 0
expect_out 'meridian-checkout \(local\)'
expect_out 'meridian-code-review@1\.0\.0'

step "6d. apm deps list (observed in 0.33.0: fails once the project has local .apm/ content)"
run apm deps list
expect_rc 1
expect_out "Invalid local package path ''"

step "6e. apm audit (content scan + drift replay)"
run apm audit
expect_rc 0
expect_out 'No drift detected'
expect_out 'no issues found'

step "6e2. apm audit --ci (lockfile consistency gate)"
run apm audit --ci
expect_rc 0
keep_out audit-ci-clean.txt

step "6f. apm install --frozen (lockfile and manifest agree)"
run apm install --frozen
expect_rc 0

step "6g. apm doctor"
run apm doctor
expect_rc 0
expect_out 'git'

step "6h. Local edit to a generated file: audit reports drift"
printf '\n- Floats are fine for display only.\n' >> .claude/rules/money-handling.md
run apm audit
expect_rc 0 "plain audit reports drift but still exits 0"
expect_out 'Drift detected: 1 file'
expect_out 'money-handling\.md'
run apm audit --ci
expect_rc 1 "the CI gate fails on drift"
expect_out 'content-integrity'
keep_out audit-ci-after-edit.txt
run apm install
expect_rc 0
fingerprint > ../../anika-after.sha256
expect_same ../../priya.sha256 ../../anika-after.sha256

step "6i. A one-off --target narrows the MCP set and rewrites the other configs"
run apm install --target claude
expect_rc 0
expect_out 'Removed stale MCP server'
expect_not_in_file .cursor/mcp.json 'ledger'
keep_out install-target-claude.txt
run apm install
expect_rc 0
fingerprint > ../../anika-final.sha256
expect_same ../../priya.sha256 ../../anika-final.sha256
cd "$WORK"

# ---------------------------------------------------------------------------
step "7. Scope: Anika installs the skill for herself at user scope"
mkdir side-project && cd side-project
run apm install -g vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-code-review#meridian-code-review-v1.0.0 --target claude
expect_rc 0
expect_out 'Installing to user scope'
cd "$HOME"   # relative paths below are under Anika's HOME
expect_file .apm/apm.yml
expect_file .apm/apm.lock.yaml
expect_file .claude/skills/meridian-code-review/SKILL.md
run_sh 'sed -n "/^targets:/,\$p" .apm/apm.yml'
cd "$WORK/side-project"
run_sh 'ls -A | wc -l'
expect_out '^0$'
run apm deps list -g
expect_rc 0
expect_out 'Dependencies \(Global\)'
cd "$WORK"

# ---------------------------------------------------------------------------
step "8. Side lab A: a registry MCP server that asks for a credential"
export HOME="$WORK/lab-home"; mkdir -p "$HOME"
git config --global init.defaultBranch main
mkdir lab-registry && cd lab-registry && git init -q
cat > apm.yml <<'EOF'
name: lab-registry
version: 1.0.0
targets:
  - claude
dependencies:
  mcp:
    - io.github.upstash/context7
EOF
run_sh 'PYTHONWARNINGS=ignore apm install < /dev/null'
expect_rc 1
expect_out 'CONTEXT7_API_KEY'
keep_out lab-registry-install.txt
expect_no_file .mcp.json
cd "$WORK"

step "9. Side lab B: a third-party Agent Plugin added to Meridian's manifest"
git clone -q "$WORK/priya/meridian-checkout" lab-plugin && cd lab-plugin
printf '    - %s\n' "$PLUGIN_REF" > ../plugin-line.txt
sed -i "/meridian-code-review-v1\.0\.0$/r ../plugin-line.txt" apm.yml
run_sh 'sed -n "/^dependencies:/,/^  mcp:/p" apm.yml'
expect_out 'awesome-copilot/plugins/context-engineering#bebb02d4'
run apm install
expect_rc 0
expect_out 'Registered 1 Agent Plugin with GitHub Copilot'
run cat .github/copilot/settings.local.json
expect_out 'context-engineering@apm'
PLUGIN_DIR=apm_modules/github/awesome-copilot/plugins/context-engineering
run_sh "find $PLUGIN_DIR -type f | LC_ALL=C sort"
expect_out 'plugin\.json'
run_sh "grep -o '\"\./[a-z/.-]*\"' $PLUGIN_DIR/plugin.json"
expect_out 'skills/context-map'
expect_no_file "$PLUGIN_DIR/skills/context-map"
expect_no_file "$PLUGIN_DIR/agents/context-architect.md"
run apm audit
expect_out 'drift check could not run'
keep_out lab-plugin-audit.txt
run apm install --frozen
expect_rc 1
expect_out 'out of sync'
keep_out lab-plugin-frozen.txt
cd "$WORK"

demo_end
