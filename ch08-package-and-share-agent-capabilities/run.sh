#!/usr/bin/env bash
# Chapter 8 demo: package and share agent capabilities with APM v0.33.0.
# Producer side: inspect the published packages, pack the team bundle,
# install the bundle and catch a tampered copy, preview registry publish.
# Consumer side: meridian-checkout depends on the team package, the skill
# arrives transitively, conflicting pins are refused, and an internal
# catalogue (an APM marketplace in a local git repo) is searched and used.
source "$(dirname "$0")/../scripts/lib.sh"
HERE="$(cd "$(dirname "$0")" && pwd)"
demo_begin ch08-package-and-share-agent-capabilities

DEMO_URL="https://github.com/vibeprogrammer/Reproducible-AI-Agent-Environments-demo"
STD_TAG="meridian-engineering-standards-v1.0.0"
CR_DEP="vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-code-review"
STD_DEP="vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-engineering-standards"
CR_LC="vibeprogrammer/reproducible-ai-agent-environments-demo/packages/meridian-code-review"
CH5_FIXTURE="$REPO_ROOT/ch05-declare-and-restore-environments-with-apm/fixture/meridian-checkout"

# Save the last command's normalized output as an evidence artifact.
keep_out() { mkdir -p "$EVIDENCE/artifacts"; _norm < "$LAST_OUT" > "$EVIDENCE/artifacts/$1"; }
# Run an apm command with the progress-spinner lines filtered out.
# pipefail keeps apm's own exit code.
SPIN='/^\s*> resolve |^\[[.#]+\]|\?25h/d'
apmq() { run_sh "set -o pipefail; $* 2>&1 | sed -E '$SPIN'"; }
generated() {
  find .agents .claude .cursor .github .vscode .mcp.json -type f 2>/dev/null \
    | LC_ALL=C sort
}
fingerprint() { generated | grep -vx '\.mcp\.json' | xargs sha256sum; }

# ---------------------------------------------------------------------------
step "1. The pinned CLI"
run apm --version
expect_rc 0
expect_out 'version 0\.33\.0'

# ---------------------------------------------------------------------------
step "2. Git-based publishing: releases are per-package tags"
run_sh "git ls-remote --tags $DEMO_URL 'refs/tags/meridian-*' | awk '{print substr(\$1,1,7), \$2}'"
expect_rc 0
expect_out 'refs/tags/meridian-code-review-v1\.1\.0$'
expect_out 'refs/tags/meridian-engineering-standards-v1\.0\.0$'
expect_out '^13749d8 refs/tags/meridian-engineering-standards-v1\.0\.0$'
expect_no_out 'refs/tags/v[0-9]'
keep_out published-tags.txt
run git clone -q --depth 1 --branch "$STD_TAG" "$DEMO_URL" src
expect_rc 0

# ---------------------------------------------------------------------------
step "3. Package shapes: a single skill vs. the team package"
cd src/packages
run_sh 'find meridian-code-review -type f | LC_ALL=C sort'
expect_out '^meridian-code-review/SKILL\.md$'
expect_out '^meridian-code-review/apm\.yml$'
run_sh 'find meridian-engineering-standards -type f | LC_ALL=C sort'
expect_out '^meridian-engineering-standards/\.apm/instructions/payment-standards\.instructions\.md$'
expect_out '^meridian-engineering-standards/\.apm/prompts/payment-pr\.prompt\.md$'
expect_no_out 'SKILL\.md'
run cat meridian-engineering-standards/apm.yml
expect_out '^version: 1\.0\.0$'
expect_out 'packages/meridian-code-review#meridian-code-review-v1\.1\.0$'
expect_out '^includes: auto$'
keep_artifact meridian-engineering-standards/apm.yml standards-apm.yml
cd "$WORK"

# ---------------------------------------------------------------------------
step "4. Producer: packing needs a lockfile, and a harness to install into"
cp -R src/packages/meridian-engineering-standards producer
cd producer
git init -q && git add -A && git commit -qm "standards 1.0.0"
apmq apm install
expect_rc 2 "no harness detected and no targets declared"
expect_out 'No harness detected'
run apm pack --dry-run
expect_rc 0
expect_out 'Would pack 3 file\(s\)'
expect_no_out 'skills/meridian-code-review'
apmq apm install --target claude
expect_rc 0
expect_out 'meridian-code-review-v1\.1\.0 @3fba23f7'
expect_file apm.lock.yaml

# ---------------------------------------------------------------------------
step "5. Producer: apm pack builds a plugin bundle with the dependency inside"
run apm pack
expect_rc 0
expect_out 'Packed 10 file\(s\)'
BUNDLE="build/meridian-engineering-standards-1.0.0"
run_sh "find $BUNDLE -type f | LC_ALL=C sort"
expect_out 'plugin\.json$'
expect_out 'instructions/payment-standards\.instructions\.md$'
expect_out 'commands/payment-pr\.md$'
expect_out 'skills/meridian-code-review/scripts/check_money_rules\.py$'
expect_out 'apm\.lock\.yaml$'
keep_out bundle-files.txt
run cat "$BUNDLE/plugin.json"
expect_out '"name": "meridian-engineering-standards"'
expect_out '"version": "1\.0\.0"'
run_sh "sed -n '/^pack:/,/^lockfile_version/p' $BUNDLE/apm.lock.yaml"
expect_out 'format: claude-plugin'
expect_out 'skills/meridian-code-review/SKILL\.md: [0-9a-f]{64}'
keep_out bundle-lock-pack-section.txt
run apm pack --archive -o dist
expect_rc 0
expect_file dist/meridian-engineering-standards-1.0.0.zip
cp -R "$BUNDLE" "$WORK/bundle"
cd "$WORK"

# ---------------------------------------------------------------------------
step "6. Bundle consumer: install the packed directory, then a tampered copy"
mkdir bundle-user && cd bundle-user && git init -q && mkdir .claude
printf 'name: bundle-user\nversion: 0.1.0\n' > apm.yml
run apm install ../bundle --target claude
expect_rc 0
expect_out 'Installed 9 file\(s\) from local bundle'
expect_file .claude/skills/meridian-code-review/SKILL.md
expect_file .claude/rules/payment-standards.md
expect_file .claude/commands/payment-pr.md
run cat apm.yml
expect_no_out 'dependencies'
cd "$WORK"
cp -R bundle tampered
printf -- '- Floats are fine for display.\n' \
  >> tampered/instructions/payment-standards.instructions.md
mkdir tamper-user && cd tamper-user && git init -q && mkdir .claude
printf 'name: tamper-user\nversion: 0.1.0\n' > apm.yml
run apm install ../tampered --target claude
expect_rc 1 "tampered bundle refused"
expect_out 'Bundle integrity check failed'
expect_out 'Hash mismatch for instructions/payment-standards\.instructions\.md'
expect_no_file .claude/rules/payment-standards.md
cd "$WORK"

# ---------------------------------------------------------------------------
step "7. Registry publishing in 0.33.0 is experimental (dry run only)"
cp -R src/packages/meridian-engineering-standards registry-pub
cd registry-pub
run apm publish --package meridian-finance/meridian-engineering-standards --dry-run
expect_rc 1
expect_out 'requires the experimental registries feature'
run apm experimental enable registries
expect_rc 0
cat >> apm.yml <<'EOF'

# Hypothetical internal registry; nothing is uploaded in this demo.
registries:
  meridian-internal:
    url: https://registry.meridian.example/apm
  default: meridian-internal
EOF
run apm publish --package meridian-finance/meridian-engineering-standards --dry-run
expect_rc 0
expect_out 'Would publish meridian-finance/meridian-engineering-standards@1\.0\.0 to meridian-internal'
expect_out 'dry-run -- nothing uploaded'
run_sh 'python3 -c "import zipfile;print(*sorted(zipfile.ZipFile(\"meridian-engineering-standards-1.0.0.zip\").namelist()),sep=\"\n\")"'
expect_out '^apm\.yml$'
expect_out '^\.apm/instructions/payment-standards\.instructions\.md$'
expect_no_out 'SKILL\.md'
run apm experimental disable registries
cd "$WORK"

# ---------------------------------------------------------------------------
step "8. Priya: meridian-checkout depends on the team package"
cp -R "$CH5_FIXTURE" priya
cd priya
mv gitignore.txt .gitignore
cp "$HERE/fixture/meridian-checkout/apm.yml" apm.yml
# The money rules now ship in the shared package; the local copy goes.
rm .apm/instructions/money-handling.instructions.md
git init -q
run_sh 'grep -n "meridian-" apm.yml | grep -v "@meridian-finance"'
expect_out 'meridian-engineering-standards#meridian-engineering-standards-v1\.0\.0'
expect_no_out 'meridian-code-review#'
apmq apm install
expect_rc 0
expect_out 'Installed 3 APM dependencies and 2 MCP servers'
keep_out priya-install.txt
expect_file .claude/skills/meridian-code-review/SKILL.md
expect_file .agents/skills/meridian-code-review/SKILL.md
expect_file .github/instructions/payment-standards.instructions.md
expect_file .claude/rules/payment-standards.md
expect_file .cursor/rules/payment-standards.mdc
expect_file .github/prompts/payment-pr.prompt.md
expect_file .claude/commands/payment-pr.md
expect_file .github/agents/payments-reviewer.agent.md
expect_no_file .github/instructions/money-handling.instructions.md
expect_in_file .claude/skills/meridian-code-review/apm.yml '^version: 1\.1\.0$'
run_sh 'generated | grep -v "skills/meridian-code-review/."'
keep_out priya-generated-files.txt

step "8a. The lockfile records the transitive dependency"
run_sh "grep -nE '^- repo_url|^  name: meridian|resolved_ref|resolved_commit|^  depth|resolved_by' apm.lock.yaml"
expect_out 'name: meridian-engineering-standards'
expect_out 'resolved_commit: 13749d8802c87e8f2e402fd376a4466980b6bbdf'
expect_out 'resolved_ref: meridian-code-review-v1\.1\.0'
expect_out 'resolved_commit: 3fba23f79f6faed7c0812d2bb31cfd7b324df562'
expect_out 'depth: 2'
expect_out 'resolved_by: vibeprogrammer/Reproducible-AI-Agent-Environments-demo$'
keep_out priya-lock-summary.txt
keep_artifact apm.lock.yaml priya-apm.lock.yaml

step "8b. Inspecting the graph (two packages from one repo)"
run apm deps tree
expect_rc 0
expect_out 'meridian-engineering-standards@1\.0\.0'
expect_out 'meridian-code-review@1\.1\.0 \(could not place in tree'
run apm deps why "$CR_LC"
expect_rc 0
expect_out '\(transitive\)'
run apm deps why vibeprogrammer/reproducible-ai-agent-environments-demo
expect_rc 1
expect_out 'matches multiple packages'
apmq apm audit --ci
expect_rc 0
expect_out 'check\(s\) passed'
keep_out priya-audit.txt
git add -A && git commit -qm "Depend on meridian-engineering-standards 1.0.0"
fingerprint > "$WORK/priya.sha256"
cd "$WORK"

# ---------------------------------------------------------------------------
step "9. Anika: a fresh clone restores the same files (Chapter 7's CI pattern)"
# On a cold checkout (no apm_modules/), `apm install --frozen` in v0.33.0
# stops before downloading anything (Chapter 7 documents this). The
# pattern: a normal install from the lockfile, prove nothing changed,
# then --frozen on the warm checkout.
git clone -q priya anika
cd anika
apmq apm install --frozen
expect_rc 1 "cold --frozen stops (as in Chapter 7)"
expect_out 'package manifest not found'
apmq apm install
expect_rc 0
run git diff --exit-code -- apm.yml apm.lock.yaml
expect_rc 0 "install changed neither apm.yml nor the lockfile"
apmq apm install --frozen
expect_rc 0
fingerprint > "$WORK/anika.sha256"
expect_same "$WORK/priya.sha256" "$WORK/anika.sha256"
cd "$WORK"

# ---------------------------------------------------------------------------
step "10. Conflicting pins: the skill directly at v1.0.1 and via the package at v1.1.0"
git clone -q priya conflict
cd conflict
cp apm.lock.yaml "$WORK/lock-before-conflict.yaml"
python3 - "$CR_DEP" <<'EOF'
import sys
dep = sys.argv[1]
s = open("apm.yml").read()
anchor = "meridian-engineering-standards-v1.0.0\n"
s = s.replace(anchor, anchor + f"    - {dep}#meridian-code-review-v1.0.1\n", 1)
open("apm.yml", "w").write(s)
EOF
run_sh 'grep -n "packages/meridian-" apm.yml'
expect_out 'meridian-code-review#meridian-code-review-v1\.0\.1'
apmq apm install
expect_rc 1 "conflicting immutable pins refused"
expect_out 'incompatible immutable'
expect_out 'requirements'
expect_out 'Align the requested refs'
keep_out conflict-install.txt
expect_same "$WORK/lock-before-conflict.yaml" apm.lock.yaml
git checkout -q apm.yml
python3 - "$CR_DEP" <<'EOF'
import sys
dep = sys.argv[1]
s = open("apm.yml").read()
anchor = "meridian-engineering-standards-v1.0.0\n"
s = s.replace(anchor, anchor + f"    - {dep}#meridian-code-review-v1.1.0\n", 1)
open("apm.yml", "w").write(s)
EOF
apmq apm install
expect_rc 0 "the same pin twice is fine"
keep_out aligned-install.txt
cd "$WORK"

# ---------------------------------------------------------------------------
step "11. The internal catalogue: an APM marketplace in its own git repo"
cp -R "$HERE/fixture/meridian-agent-catalog" catalog
cd catalog
git init -q
run apm marketplace check
expect_rc 0
expect_out 'All 2 entries OK'
run apm pack
expect_rc 0
expect_out 'Built marketplace\.json \[claude\] \(2 package\(s\)\)'
expect_file .claude-plugin/marketplace.json
run cat .claude-plugin/marketplace.json
expect_out '"source": "git-subdir"'
expect_out '"ref": "meridian-engineering-standards-v1\.0\.0"'
expect_out '"sha": "13749d8802c87e8f2e402fd376a4466980b6bbdf"'
expect_out '"ref": "meridian-code-review-v1\.1\.0"'
expect_no_out 'meridian-code-review-v1\.2\.0'
keep_artifact .claude-plugin/marketplace.json marketplace.json
git add -A && git commit -qm "Catalogue 1.0.0"
cd "$WORK"

step "11a. Lena: find and install from the catalogue by name"
mkdir lena && cd lena && git init -q
printf 'name: lena-sandbox\nversion: 0.1.0\ntargets:\n  - cursor\n' > apm.yml
run apm marketplace add "$WORK/catalog" --name meridian
expect_rc 0
expect_out "Marketplace 'meridian' registered \(2 plugins\)"
run apm marketplace browse meridian
expect_rc 0
expect_out 'meridian-engineering-standards'
run apm search standards@meridian
expect_rc 0
expect_out 'meridian-engineering-standards@meridian'
expect_no_out 'meridian-code-review@meridian'
apmq apm install meridian-engineering-standards@meridian
expect_rc 0
expect_out 'meridian-engineering-standards-v1\.0\.0 @13749d88'
expect_out 'meridian-code-review-v1\.1\.0 @3fba23f7'
run cat apm.yml
expect_out 'path: packages/meridian-engineering-standards'
expect_out 'ref: meridian-engineering-standards-v1\.0\.0'
keep_artifact apm.yml lena-apm.yml
run_sh "grep -nE '^  name: meridian|discovered_via|marketplace_plugin_name|^  depth' apm.lock.yaml"
expect_out 'discovered_via: meridian'
expect_out 'marketplace_plugin_name: meridian-engineering-standards'
expect_file .cursor/rules/payment-standards.mdc
expect_file .agents/skills/meridian-code-review/SKILL.md
cd "$WORK"

# ---------------------------------------------------------------------------
step "12. Experimental feature list (for the record)"
run apm experimental list
expect_rc 0
keep_out experimental-list.txt

demo_end
