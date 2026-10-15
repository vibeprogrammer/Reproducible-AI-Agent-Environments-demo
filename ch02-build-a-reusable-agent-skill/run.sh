#!/usr/bin/env bash
# Chapter 2: Build a Reusable Agent Skill
# Builds Meridian's code-review skill in a clean workspace, validates it
# against the Agent Skills specification, runs its checker script on sample
# diffs, and installs the published package with APM v0.33.0 for two targets
# at project scope and one at user scope.
source "$(dirname "$0")/../scripts/lib.sh"
demo_begin ch02-build-a-reusable-agent-skill

DEMO_DIR="$REPO_ROOT/ch02-build-a-reusable-agent-skill"
PKG_SRC="$REPO_ROOT/packages/meridian-code-review"
PKG_REF="vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-code-review#meridian-code-review-v1.0.0"
SKILLS_REF_COMMIT="69ef37e9424c0a7ea9dd2293b559e43ec8176379"
export APM_PROGRESS=never   # documented env var: no install TUI in logs

# ---------------------------------------------------------------------------
step "1. Build the skill folder from scratch"
mkdir -p meridian-code-review/scripts meridian-code-review/references \
         meridian-code-review/assets
for f in SKILL.md scripts/check_money_rules.py references/money-rules.md \
         references/false-positives.md assets/review-report-template.md \
         apm.yml; do
  cp "$PKG_SRC/$f" "meridian-code-review/$f"
done
run_sh 'find meridian-code-review -type f | sort'
expect_rc 0
expect_out 'meridian-code-review/SKILL.md'
run_sh 'wc -l meridian-code-review/SKILL.md'
expect_out '^[0-9]+ '
run_sh 'sed -n "1,/^# /p" meridian-code-review/SKILL.md'
expect_out '^name: meridian-code-review$'
keep_artifact meridian-code-review/SKILL.md SKILL.md

# ---------------------------------------------------------------------------
step "2. Validate against the spec with the reference validator (skills-ref)"
python3 -m venv .venv >/dev/null 2>&1
./.venv/bin/pip install --quiet --disable-pip-version-check \
  "git+https://github.com/agentskills/agentskills@${SKILLS_REF_COMMIT}#subdirectory=skills-ref" \
  > pip.log 2>&1
SR=./.venv/bin/skills-ref
run "$SR" validate meridian-code-review
expect_rc 0 "skills-ref validate"
expect_out 'Valid skill'
run "$SR" read-properties meridian-code-review
expect_rc 0
expect_out '"name": "meridian-code-review"'
run "$SR" to-prompt meridian-code-review
expect_out '<name>'
_norm < "$LAST_OUT" > catalog-entry.xml; keep_artifact catalog-entry.xml

step "2b. The validator rejects broken copies"
# A directory name that does not match the frontmatter name.
cp -r meridian-code-review code-review
run "$SR" validate code-review
expect_rc_nonzero "name/directory mismatch"
expect_out "must match skill name"
# A SKILL.md with no description.
mkdir -p no-description && cp -r meridian-code-review/. no-description/
python3 - <<'EOF'
import re, pathlib
p = pathlib.Path("no-description/SKILL.md")
t = p.read_text()
t = re.sub(r"description: >-\n(  .*\n)+", "", t, count=1)
t = t.replace("name: meridian-code-review", "name: no-description")
p.write_text(t)
EOF
run "$SR" validate no-description
expect_rc_nonzero "missing description"
expect_out "description"

# ---------------------------------------------------------------------------
step "3. Scan the skill for hidden Unicode with APM"
run apm audit --file meridian-code-review/SKILL.md
expect_rc 0
expect_out 'no issues found'
run apm audit --file meridian-code-review/references/money-rules.md
expect_rc 0
expect_out 'no issues found'

# ---------------------------------------------------------------------------
step "4. Run the checker script on sample diffs"
# The checker runs inside its own folder so we can prove it writes nothing.
mkdir -p review && cp -r meridian-code-review "$DEMO_DIR/fixtures/bad.diff" \
  "$DEMO_DIR/fixtures/good.diff" review/
mkdir -p review/patched && cp -r "$DEMO_DIR/fixtures/base/." review/patched/
( cd review/patched && git apply ../bad.diff )
cd review
CHECK="python3 meridian-code-review/scripts/check_money_rules.py"
snapshot() { find . -type f -print0 | sort -z | xargs -0 sha256sum; }
snapshot > ../before.sha256
run_sh "$CHECK --diff bad.diff"
expect_rc 1 "findings present"
expect_out 'MR001 parseFloat'
expect_out 'MR001 decimal literal'
expect_out 'MR002 '
expect_out 'MR003 '
expect_out "MR004 currency 'eur'"
expect_out '^6 finding\(s\)$'
cp "$LAST_OUT" ../bad-findings.txt; keep_artifact ../bad-findings.txt
run_sh "$CHECK --diff good.diff"
expect_rc 0 "clean change"
expect_out '^0 finding\(s\)$'
run_sh "$CHECK --diff bad.diff --format json"
expect_rc 1
expect_out '"count": 6'
cp "$LAST_OUT" ../bad-findings.json; keep_artifact ../bad-findings.json
run_sh "cat bad.diff | $CHECK --diff -"
expect_rc 1 "diff on stdin"
run_sh "$CHECK --files patched/src/checkout/charge.ts"
expect_rc 1 "whole-file mode"
expect_out 'MR002 '
run_sh "$CHECK --files does-not-exist.ts"
expect_rc 2 "unreadable input"
run_sh "$CHECK"
expect_rc 2 "no input given"
snapshot > ../after.sha256
cd ..
expect_same before.sha256 after.sha256

# ---------------------------------------------------------------------------
step "5. Install the published package with APM (project scope)"
mkdir -p meridian-checkout && cd meridian-checkout && git init -q
run apm install "$PKG_REF" --target claude,copilot
expect_rc 0 "apm install from tag"
expect_out 'Skill integrated -> \.agents/skills/, \.claude/skills/'
run_sh 'find .claude .agents -type f | sort'
expect_file .claude/skills/meridian-code-review/SKILL.md
expect_file .claude/skills/meridian-code-review/scripts/check_money_rules.py
expect_file .agents/skills/meridian-code-review/SKILL.md
expect_file .agents/skills/meridian-code-review/references/money-rules.md
expect_same .claude/skills/meridian-code-review/SKILL.md ../meridian-code-review/SKILL.md
expect_same .agents/skills/meridian-code-review/SKILL.md ../meridian-code-review/SKILL.md
expect_same .claude/skills/meridian-code-review/scripts/check_money_rules.py \
  ../meridian-code-review/scripts/check_money_rules.py
run cat apm.yml
expect_out 'meridian-code-review#meridian-code-review-v1.0.0'
run_sh 'grep -E "repo_url|virtual_path|resolved_ref|resolved_commit" apm.lock.yaml'
expect_out 'resolved_ref: meridian-code-review-v1.0.0'
expect_out 'resolved_commit: [0-9a-f]{40}'
keep_artifact apm.yml consumer-apm.yml
keep_artifact apm.lock.yaml consumer-apm.lock.yaml
run_sh 'python3 .claude/skills/meridian-code-review/scripts/check_money_rules.py --diff ../review/bad.diff | tail -1'
expect_out '^6 finding\(s\)$'
cd ..

# ---------------------------------------------------------------------------
step "6. Install at user scope (-g) for Claude Code"
mkdir -p elsewhere && cd elsewhere
run apm install -g "$PKG_REF" --target claude
expect_rc 0 "user-scope install"
expect_no_file .claude
cd "$HOME"
run_sh 'find .claude -type f | sort'
expect_file .claude/skills/meridian-code-review/SKILL.md
expect_file .apm/apm.yml
run_sh 'grep -A3 "^dependencies" .apm/apm.yml'
expect_out 'meridian-code-review#meridian-code-review-v1.0.0'
cd "$WORK"

demo_end
